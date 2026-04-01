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
        The bcache block device path.
        For single-backing setups this is always `/dev/bcache0`.
        For multi-backing setups, set this explicitly.
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
          backing_basename="$(basename "$(readlink -f "$backing_dev")")"

          # Idempotency: if the bcache device already exists with our backing device, skip creation
          if [ -b "${config.device}" ] && \
             [ -e "/sys/block/${devBasename}/bcache/backing_dev_name" ] && \
             [ "$(cat "/sys/block/${devBasename}/bcache/backing_dev_name")" = "$backing_basename" ]; then
            : # bcache device already active with correct backing — nothing to do
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
            make-bcache \
              -C "$cache_dev" \
              -B "$backing_dev" \
              --force \
              ${lib.optionalString (config.cacheMode == "writeback") "--writeback"} \
              ${lib.concatStringsSep " " (map lib.escapeShellArg config.extraCacheArgs)} \
              ${lib.concatStringsSep " " (map lib.escapeShellArg config.extraBackingArgs)}

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

          # Set cache mode
          echo "${config.cacheMode}" > "/sys/block/${devBasename}/bcache/cache_mode"

          ${lib.optionalString (config.content != null) config.content._create}
        '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = lib.optionalAttrs (config.content != null) config.content._mount;
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
