{
  config,
  options,
  lib,
  diskoLib,
  ...
}:
let
  devBasename = builtins.baseNameOf config.device;
  sysfs = "/sys/block/${devBasename}/bcache";
  setName = lib.escapeShellArg config.name;

  # Sets cache_dev/backing_dev from the members registered by bcache_cache and
  # bcache_backing, plus their resolved kernel names.
  readMembers = ''
    for role in cache backing; do
      if ! test -s "$disko_devices_dir"/bcache_''${role}_${setName}; then
        printf "\033[31mERROR:\033[0m No %s device found for bcache set %s!\n" "$role" ${setName} >&2
        exit 1
      fi
    done
    cache_dev=$(head -n1 "$disko_devices_dir"/bcache_cache_${setName})
    backing_dev=$(head -n1 "$disko_devices_dir"/bcache_backing_${setName})
  '';

  resolveMembers = ''
    cache_resolved="$(readlink -f "$cache_dev")"
    backing_resolved="$(readlink -f "$backing_dev")"
    if [ "$cache_resolved" = "$backing_resolved" ]; then
      printf "\033[31mERROR:\033[0m bcache set %s uses the same block device for cache and backing: %s\n" ${setName} "$cache_resolved" >&2
      exit 1
    fi
    backing_basename="$(basename "$backing_resolved")"
  '';

  registerHelpers = ''
    is_registered() {
      [ -e "/sys/class/block/$1/bcache" ]
    }

    register_bcache_member() {
      local resolved="$1"
      local block_name
      local i

      block_name="$(basename "$resolved")"
      if ! bcache-super-show "$resolved" >&2; then
        printf "\033[31mERROR:\033[0m %s does not contain a bcache superblock\n" "$resolved" >&2
        return 1
      fi

      is_registered "$block_name" && return 0
      # A concurrent udev registration may win the race and fail this write.
      printf '%s\n' "$resolved" > /sys/fs/bcache/register || true

      for i in $(seq 1 30); do
        is_registered "$block_name" && return 0
        udevadm settle --timeout=1 || true
        sleep 1
      done

      printf "\033[31mERROR:\033[0m bcache member %s did not register\n" "$resolved" >&2
      return 1
    }

    wait_for_assembly() {
      local expected_backing="$1"
      local i

      for i in $(seq 1 60); do
        if [ -b "${config.device}" ] && \
           [ "$(cat "${sysfs}/backing_dev_name" 2>/dev/null)" = "$expected_backing" ] && \
           [ -e "${sysfs}/cache" ]; then
          return 0
        fi
        udevadm settle --timeout=1 || true
        sleep 1
      done
      return 1
    }
  '';

  # Fails unless config.device is backed by our backing member and attached to
  # the cache set recorded in our cache member's superblock.
  verifyAssembled = ''
    if [ ! -b "${config.device}" ]; then
      printf "\033[31mERROR:\033[0m bcache device ${config.device} did not appear\n" >&2
      exit 1
    fi
    actual_backing_basename="$(cat "${sysfs}/backing_dev_name" 2>/dev/null || true)"
    if [ "$actual_backing_basename" != "$backing_basename" ]; then
      printf "\033[31mERROR:\033[0m bcache device ${config.device} is attached to backing %s, expected %s\n" "$actual_backing_basename" "$backing_basename" >&2
      exit 1
    fi
    expected_cset=""
    while read -r key value; do
      if [ "$key" = cset.uuid ]; then
        expected_cset="$value"
      fi
    done < <(bcache-super-show "$cache_resolved")
    actual_cset=""
    if [ -e "${sysfs}/cache" ]; then
      actual_cset="$(basename "$(readlink -f "${sysfs}/cache")")"
    fi
    if [ -z "$expected_cset" ] || [ "$actual_cset" != "$expected_cset" ]; then
      printf "\033[31mERROR:\033[0m bcache device ${config.device} is not attached to cache set %s of %s (attached: %s)\n" "$expected_cset" "$cache_dev" "''${actual_cset:-none}" >&2
      exit 1
    fi

    echo "${config.cacheMode}" > "${sysfs}/cache_mode"
  '';
in
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Name of the bcache set.";
      example = "main";
    };
    type = lib.mkOption {
      type = lib.types.enum [ "bcache" ];
      internal = true;
      description = "Type";
    };
    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/bcache0";
      description = ''
        The bcache block device path. This must be a concrete `/dev/bcacheN`
        path because generated scripts use `/sys/block/<bcacheN>`.

        The current implementation supports exactly one `bcache_cache`
        partition and one `bcache_backing` partition per bcache set.
        Member devices must be unique across all bcache sets and cannot be
        reused between cache and backing roles.
        Mount-only assembly requires existing bcache superblocks on both
        members and never creates bcache metadata.
      '';
    };
    cacheMode = lib.mkOption {
      type = lib.types.enum [
        "writethrough"
        "writeback"
        "writearound"
        "none"
      ];
      default = "writethrough";
      description = "Cache mode for the bcache device.";
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra arguments appended to the single `make-bcache -C <cache> -B <backing>`
        invocation. Its options apply to both members.
      '';
      example = [
        "--block"
        "4k"
        "--bucket"
        "2M"
        "--discard"
      ];
    };
    content = diskoLib.deviceType {
      parent = config;
      device = config.device;
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = diskoLib.jsonType;
      default = lib.optionalAttrs (config.content != null) (
        config.content._meta [
          "bcache"
          config.name
        ]
      );
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        ${readMembers}
        modprobe bcache
        ${resolveMembers}
        ${registerHelpers}
        ${diskoLib.bcacheReleaseMembers}

        fresh_bcache=0
        # Idempotency: keep an assembled set that already uses our backing device
        if [ -b "${config.device}" ] && \
           [ "$(cat "${sysfs}/backing_dev_name" 2>/dev/null)" = "$backing_basename" ]; then
          bcache-super-show "$cache_resolved" >&2
          bcache-super-show "$backing_resolved" >&2
        else
          fresh_bcache=1
          # Release only our members (a stale set from an earlier run); other
          # bcache sets on this machine keep running.
          bcache_release_members "$cache_resolved" "$backing_resolved"

          # --force replaces bcache metadata, but make-bcache still rejects
          # other filesystem signatures. Clear the unassembled members before
          # creating a fresh set; the idempotent branch above preserves them.
          wipefs --all --force "$cache_resolved" "$backing_resolved"

          echo "Creating bcache set ${setName} with cache $cache_dev ($cache_resolved) and backing $backing_dev ($backing_resolved)" >&2
          make-bcache \
            -C "$cache_dev" \
            -B "$backing_dev" \
            --force \
            ${lib.escapeShellArgs config.extraArgs}

          # Writing a superblock does not guarantee that udev registers the
          # members before content creation, so register them explicitly.
          udevadm settle --timeout=10 || true
          register_bcache_member "$cache_resolved"
          register_bcache_member "$backing_resolved"
          wait_for_assembly "$backing_basename" || true
        fi

        ${verifyAssembled}

        if [ "$fresh_bcache" = 1 ]; then
          # A fresh bcache device maps backing data shifted by `data_offset`
          # without zeroing it, so stale signatures from earlier backing
          # content can surface and make content `_create` skip formatting.
          wipefs --all --force "${config.device}" >&2
        fi

        ${lib.optionalString (config.content != null) config.content._create}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default =
        let
          content = lib.optionalAttrs (config.content != null) config.content._mount;
        in
        {
          dev = ''
            ${readMembers}
            modprobe bcache
            ${registerHelpers}
            wait_for_block() {
              local path="$1"
              local i

              for i in $(seq 1 60); do
                [ -b "$path" ] && return 0
                udevadm settle --timeout=1 || true
                sleep 1
              done

              printf "\033[31mERROR:\033[0m timed out waiting for block device %s\n" "$path" >&2
              return 1
            }
            for i in $(seq 1 30); do
              [ -e /sys/fs/bcache/register ] && break
              sleep 1
            done
            wait_for_block "$cache_dev"
            wait_for_block "$backing_dev"
            ${resolveMembers}
            register_bcache_member "$cache_resolved"
            register_bcache_member "$backing_resolved"
            wait_for_assembly "$backing_basename" || true

            ${verifyAssembled}
            ${content.dev or ""}
          '';
          fs = content.fs or { };
        };
    };
    _unmount = diskoLib.mkUnmountOption {
      inherit config options;
      default =
        let
          content = lib.optionalAttrs (config.content != null) config.content._unmount;
        in
        {
          fs = content.fs or { };
          dev = ''
            ${content.dev or ""}
            # Stop the device, then unregister the cache set it was attached to.
            # Never write `detach`: it permanently drops the cache from the
            # backing superblock, so the next mount would run without a cache.
            if [ -e "${sysfs}/stop" ]; then
              cset=""
              if [ -e "${sysfs}/cache" ]; then
                cset="$(readlink -f "${sysfs}/cache")"
              fi
              echo 1 > "${sysfs}/stop"
              for i in $(seq 1 30); do
                [ -e "/sys/block/${devBasename}" ] || break
                udevadm settle --timeout=1 || true
                sleep 1
              done
              if [ -n "$cset" ] && [ -e "$cset/unregister" ]; then
                echo 1 > "$cset/unregister"
              fi
              udevadm settle --timeout=10 || true
            fi
          '';
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = [
        {
          boot.bcache.enable = true;
          boot.initrd.kernelModules = [ "bcache" ];
        }
      ]
      ++ lib.optional (config.content != null) config.content._config;
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default =
        pkgs:
        [
          pkgs.bcache-tools
          pkgs.kmod
          pkgs.util-linux
        ]
        ++ lib.optionals (config.content != null) (config.content._pkgs pkgs);
      description = "Packages";
    };
  };
}
