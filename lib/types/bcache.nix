{
  config,
  options,
  lib,
  diskoLib,
  rootMountPoint,
  ...
}:
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
    extraCacheArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments passed to `make-bcache -C` for the cache device.";
    };
    extraBackingArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments passed to `make-bcache -B` for the backing device.";
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
      default =
        let
          devBasename = builtins.baseNameOf config.device;
        in
        ''
          # Read cache and backing device paths from temp directory
          if ! test -s "$disko_devices_dir/bcache_cache_${lib.escapeShellArg config.name}"; then
            printf "\033[31mERROR:\033[0m No cache device found for bcache set \"${config.name}\"!\n" >&2
            exit 1
          fi
          if ! test -s "$disko_devices_dir/bcache_backing_${lib.escapeShellArg config.name}"; then
            printf "\033[31mERROR:\033[0m No backing device found for bcache set \"${config.name}\"!\n" >&2
            exit 1
          fi

          cache_dev=$(head -n1 "$disko_devices_dir/bcache_cache_${lib.escapeShellArg config.name}")
          backing_dev=$(head -n1 "$disko_devices_dir/bcache_backing_${lib.escapeShellArg config.name}")

          modprobe bcache

          # Resolve symlink to kernel device name for sysfs matching
          cache_resolved="$(readlink -f "$cache_dev")"
          backing_resolved="$(readlink -f "$backing_dev")"
          if [ "$cache_resolved" = "$backing_resolved" ]; then
            printf "\033[31mERROR:\033[0m bcache set \"${config.name}\" uses the same block device for cache and backing: %s\n" "$cache_resolved" >&2
            exit 1
          fi
          backing_basename="$(basename "$backing_resolved")"

          verify_bcache_superblock() {
            local role="$1"
            local dev="$2"
            local resolved

            resolved="$(readlink -f "$dev")"
            echo "Verifying bcache $role superblock on $dev -> $resolved" >&2
            if ! bcache-super-show "$resolved" >&2; then
              printf "\033[31mERROR:\033[0m make-bcache did not create a valid bcache %s superblock on %s (%s)\n" "$role" "$dev" "$resolved" >&2
              exit 1
            fi
          }

          # Idempotency: if the bcache device already exists with our backing device, skip creation
          if [ -b "${config.device}" ] && \
             [ -e "/sys/block/${devBasename}/bcache/backing_dev_name" ] && \
             [ "$(cat "/sys/block/${devBasename}/bcache/backing_dev_name")" = "$backing_basename" ]; then
            verify_bcache_superblock cache "$cache_dev"
            verify_bcache_superblock backing "$backing_dev"
          else
            # Teardown stale bcache device if it exists (destroy-format-mount scenario)
            if [ -e "/sys/block/${devBasename}/bcache/stop" ]; then
              echo 1 > "/sys/block/${devBasename}/bcache/stop" 2>/dev/null || true
            fi
            # Unregister any active cache sets
            find /sys/fs/bcache -maxdepth 1 -mindepth 1 -type d -exec sh -c '
              for cset; do
                if [ -e "$cset/unregister" ]; then
                  echo 1 > "$cset/unregister" 2>/dev/null || true
                fi
              done
            ' _ {} + 2>/dev/null || true
            udevadm settle --timeout=10
            # Wait for the bcache device to fully disappear
            for i in $(seq 1 30); do
              [ -b "${config.device}" ] || break
              sleep 1
            done

            # Create bcache set — --force handles pre-existing superblocks
            echo "Creating bcache set \"${config.name}\" with cache $cache_dev ($cache_resolved) and backing $backing_dev ($backing_resolved)" >&2
            make-bcache \
              -C "$cache_dev" \
              -B "$backing_dev" \
              --force \
              ${lib.optionalString (config.cacheMode == "writeback") "--writeback"} \
              ${lib.concatStringsSep " " (map lib.escapeShellArg config.extraCacheArgs)} \
              ${lib.concatStringsSep " " (map lib.escapeShellArg config.extraBackingArgs)}

            verify_bcache_superblock cache "$cache_dev"
            verify_bcache_superblock backing "$backing_dev"

            # Wait for the bcache block device to appear
            for i in $(seq 1 60); do
              [ -b "${config.device}" ] && break
              sleep 1
            done
          fi

          if [ ! -b "${config.device}" ]; then
            printf "\033[31mERROR:\033[0m bcache device ${config.device} did not appear\n" >&2
            exit 1
          fi

          if [ ! -e "/sys/block/${devBasename}/bcache/backing_dev_name" ]; then
            printf "\033[31mERROR:\033[0m bcache device ${config.device} has no backing_dev_name in sysfs\n" >&2
            exit 1
          fi

          actual_backing_basename="$(cat "/sys/block/${devBasename}/bcache/backing_dev_name")"
          if [ "$actual_backing_basename" != "$backing_basename" ]; then
            printf "\033[31mERROR:\033[0m bcache device ${config.device} is attached to backing %s, expected %s\n" "$actual_backing_basename" "$backing_basename" >&2
            exit 1
          fi

          # Set cache mode
          echo "${config.cacheMode}" > "/sys/block/${devBasename}/bcache/cache_mode"

          ${lib.optionalString (config.content != null) config.content._create}
        '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default =
        let
          devBasename = builtins.baseNameOf config.device;
          content = lib.optionalAttrs (config.content != null) config.content._mount;
        in
        {
          dev = ''
            if ! test -s "$disko_devices_dir/bcache_cache_${lib.escapeShellArg config.name}"; then
              printf "\033[31mERROR:\033[0m No cache device found for bcache set \"${config.name}\"!\n" >&2
              exit 1
            fi
            if ! test -s "$disko_devices_dir/bcache_backing_${lib.escapeShellArg config.name}"; then
              printf "\033[31mERROR:\033[0m No backing device found for bcache set \"${config.name}\"!\n" >&2
              exit 1
            fi

            cache_dev=$(head -n1 "$disko_devices_dir/bcache_cache_${lib.escapeShellArg config.name}")
            backing_dev=$(head -n1 "$disko_devices_dir/bcache_backing_${lib.escapeShellArg config.name}")

            wait_for_path() {
              local path="$1"
              local i

              for i in $(seq 1 30); do
                [ -e "$path" ] && return 0
                udevadm settle --timeout=1 || true
                sleep 1
              done

              printf "\033[31mERROR:\033[0m timed out waiting for %s\n" "$path" >&2
              return 1
            }

            wait_for_block() {
              local path="$1"
              local i

              for i in $(seq 1 60); do
                [ -b "$path" ] && return 0
                udevadm settle --timeout=1 || true
                sleep 1
              done

              printf "\033[31mERROR:\033[0m timed out waiting for bcache device %s\n" "$path" >&2
              return 1
            }

            wait_for_member_registration() {
              local block_name="$1"
              local i

              for i in $(seq 1 30); do
                if [ -e "/sys/class/block/$block_name/bcache" ] || [ -e "/sys/block/$block_name/bcache" ]; then
                  return 0
                fi
                udevadm settle --timeout=1 || true
                sleep 1
              done

              printf "\033[31mERROR:\033[0m bcache member %s did not register\n" "$block_name" >&2
              return 1
            }

            register_bcache_member() {
              local dev="$1"
              local resolved
              local block_name

              wait_for_block "$dev"
              resolved="$(readlink -f "$dev")"
              if [ ! -b "$resolved" ]; then
                printf "\033[31mERROR:\033[0m resolved bcache member %s is not a block device\n" "$resolved" >&2
                return 1
              fi
              block_name="$(basename "$resolved")"

              if ! bcache-super-show "$resolved" >/dev/null; then
                printf "\033[31mERROR:\033[0m %s does not contain a bcache superblock\n" "$resolved" >&2
                return 1
              fi

              if [ -e "/sys/class/block/$block_name/bcache" ] || [ -e "/sys/block/$block_name/bcache" ]; then
                return 0
              fi

              if ! printf '%s\n' "$resolved" > /sys/fs/bcache/register; then
                if [ -e "/sys/class/block/$block_name/bcache" ] || [ -e "/sys/block/$block_name/bcache" ]; then
                  return 0
                fi
                if [ -b "${config.device}" ] && \
                   [ -e "/sys/block/${devBasename}/bcache/backing_dev_name" ] && \
                   [ "$(cat "/sys/block/${devBasename}/bcache/backing_dev_name")" = "$block_name" ]; then
                  return 0
                fi
                printf "\033[31mERROR:\033[0m failed to register bcache member %s\n" "$resolved" >&2
                return 1
              fi

              wait_for_member_registration "$block_name"
            }

            modprobe bcache
            wait_for_path /sys/fs/bcache/register
            wait_for_block "$cache_dev"
            wait_for_block "$backing_dev"
            expected_backing_basename="$(basename "$(readlink -f "$backing_dev")")"
            register_bcache_member "$cache_dev"
            register_bcache_member "$backing_dev"
            udevadm settle --timeout=10 || true

            if [ ! -b "${config.device}" ]; then
              wait_for_block "${config.device}"
            fi

            if [ ! -b "${config.device}" ]; then
              printf "\033[31mERROR:\033[0m bcache device ${config.device} did not appear\n" >&2
              exit 1
            fi

            if [ ! -e "/sys/block/${devBasename}/bcache/backing_dev_name" ]; then
              printf "\033[31mERROR:\033[0m bcache device ${config.device} has no backing_dev_name in sysfs\n" >&2
              exit 1
            fi

            actual_backing_basename="$(cat "/sys/block/${devBasename}/bcache/backing_dev_name")"
            if [ "$actual_backing_basename" != "$expected_backing_basename" ]; then
              printf "\033[31mERROR:\033[0m bcache device ${config.device} is attached to backing %s, expected %s\n" "$actual_backing_basename" "$expected_backing_basename" >&2
              exit 1
            fi

            if [ -e "/sys/block/${devBasename}/bcache/cache_mode" ]; then
              echo "${config.cacheMode}" > "/sys/block/${devBasename}/bcache/cache_mode"
            fi
            ${content.dev or ""}
          '';
          fs = content.fs or { };
        };
    };
    _unmount = diskoLib.mkUnmountOption {
      inherit config options;
      default =
        let
          devBasename = builtins.baseNameOf config.device;
          content = lib.optionalAttrs (config.content != null) config.content._unmount;
        in
        {
          fs = content.fs or { };
          dev = ''
            ${content.dev or ""}
            # Stop the bcache device to release cache and backing devices
            if [ -e "/sys/block/${devBasename}/bcache/detach" ]; then
              echo 1 > "/sys/block/${devBasename}/bcache/detach" 2>/dev/null || true
            fi
            if [ -e "/sys/block/${devBasename}/bcache/stop" ]; then
              echo 1 > "/sys/block/${devBasename}/bcache/stop" 2>/dev/null || true
            fi
            # Unregister cache sets
            find /sys/fs/bcache -maxdepth 1 -mindepth 1 -type d -exec sh -c '
              for cset; do
                if [ -e "$cset/unregister" ]; then
                  echo 1 > "$cset/unregister" 2>/dev/null || true
                fi
              done
            ' _ {} + 2>/dev/null || true
            udevadm settle --timeout=10
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
