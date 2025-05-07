{
  config,
  diskoLib,
  lib,
  options,
  parent,
  rootMountPoint,
  ...
}:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Name of the bcachefs filesystem.";
      example = "main_bcachefs_filesystem";
    };
    type = lib.mkOption {
      type = lib.types.enum [ "bcachefs_filesystem" ];
      internal = true;
      description = "Type.";
    };
    extraFormatArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments passed to the `bcachefs format` command.";
      example = [
        "--compression=lz4"
        "--background_compression=lz4"
      ];
    };
    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "X-mount.mkdir" ];
      description = ''
        Options to pass to mount.
        The "X-mount.mkdir" option is always automatically added.
      '';
      example = [
        "noatime"
        "verbose"
      ];
    };
    mountpoint = lib.mkOption {
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = "Path to mount the bcachefs filesystem to.";
      example = "/";
    };
    uuid = lib.mkOption {
      type = lib.types.strMatching "[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}";
      default =
        let
          # Generate a deterministic but random-looking UUID based on the filesystem name
          # This avoids the need for impure access to nixpkgs at evaluation time
          hash = builtins.hashString "sha256" "${config.name}";
          hexChars = builtins.substring 0 32 hash;
          p1 = builtins.substring 0 8 hexChars;
          p2 = builtins.substring 8 4 hexChars;
          p3 = builtins.substring 12 4 hexChars;
          p4 = builtins.substring 16 4 hexChars;
          p5 = builtins.substring 20 12 hexChars;
        in
        "${p1}-${p2}-${p3}-${p4}-${p5}";
      defaultText = "generated deterministically based on filesystem name";
      example = "809b3a2b-828a-4730-95e1-75b6343e415a";
      description = ''
        The UUID of the bcachefs filesystem.
        If not provided, a deterministic UUID will be generated based on the filesystem name.
      '';
    };
    passwordFile = lib.mkOption {
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = ''
        Path to the file containing the password for encryption.
        Setting this option will automatically cause the `--encrypted` option to be passed to `bcachefs format` and cause the filesystem to have encryption enabled.
      '';
      example = "/tmp/disk.key";
    };
    subvolumes = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { config, ... }:
          {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                default = config._module.args.name;
                description = ''
                  Path of the subvolume within the filesystem.
                  Leading forward slashes are automatically removed.
                '';
                example = "subvolumes/home";
              };
              type = lib.mkOption {
                type = lib.types.enum [ "bcachefs_subvolume" ];
                default = "bcachefs_subvolume";
                internal = true;
                description = "Type.";
              };
              mountOptions = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = lib.naturalSort [
                  "X-mount.mkdir"
                  "X-mount.subdir=${lib.removePrefix "/" config.name}"
                ];
                description = ''
                  Options to pass to mount.
                  The "X-mount.mkdir" and "X-mount.subdir" options are always automatically added.
                '';
              };
              mountpoint = lib.mkOption {
                type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
                default = null;
                description = "Path to mount the subvolume to.";
                example = "/";
              };
            };
          }
        )
      );
      default = { };
      description = "List of subvolumes to define.";
      example = {
        "subvolumes/root" = {
          mountpoint = "/";
          extraFormatArgs = [
            "--compression=lz4"
            "--background_compression=lz4"
          ];
          mountOptions = [
            "verbose"
          ];
        };
        "subvolumes/home" = {
          mountpoint = "/home";
        };
      };
    };
    _parent = lib.mkOption {
      internal = true;
      default = parent;
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = dev: { };
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      # This sets a string variable containing arguments to be passed to the `bcachefs format` command.
      # This string will consist of `--label` and other arguments that correspond to the values of the `label` and `extraFormatArgs` attributes, respectively,
      # from each of the bcachefs devices in this filesystem specified in the configuration.
      # Then, it sets the `default` attribute to a string containing shell commands that calls the `bcachefs format` command, passing in the arguments generated, as well as a `--uuid` value.
      default = ''
        if ! test -s "$disko_devices_dir/bcachefs-${config.name}"; then
          printf "\033[31mERROR:\033[0m No devices found for bcachefs filesystem \"${config.name}\"!\nDid you forget to add some or misspell the filesystem name?\n" >&2;
          exit 1;
        fi;

        # Create the filesystem.
        (
          # Empty out $@.
          set --;
          # Collect devices and arguments to $@.
          while IFS= read -r line; do
            # Append current line as a new positional parameter
            set -- "$@" "$line";
          done < "$disko_devices_dir/bcachefs-${config.name}";

          # Format the filesystem with all devices and arguments.
          if ! blkid -o export "$(blkid -lU ${config.uuid})" | grep -q 'TYPE=bcachefs' >&2 2>&1; then
            bcachefs format \
              "$@" \
              --uuid="${config.uuid}" \
              ${lib.concatStringsSep " \\\n" config.extraFormatArgs} \
              ${
                lib.optionalString (config.passwordFile != null) ''--encrypted < "${config.passwordFile}"''
              };
          fi;
        );

        # Mount the bcachefs filesystem onto a temporary directory,
        # then, create the subvolumes from inside of that directory.
        ${lib.optionalString (config.subvolumes != { }) ''
          if blkid -o export "$(blkid -lU ${config.uuid})" | grep -q 'TYPE=bcachefs' >&2 2>&1; then
            ${lib.concatMapStrings (subvolume: ''
              (
                TEMPDIR="$(mktemp -d)";
                MNTPOINT="$(mktemp -d)";
                ${lib.optionalString (
                  config.passwordFile != null
                ) ''bcachefs unlock -k session "/dev/disk/by-uuid/${config.uuid}" < "${config.passwordFile}";''}
                bcachefs mount \
                  -o "${lib.concatStringsSep "," (lib.unique ([ "X-mount.mkdir" ] ++ config.mountOptions))}" \
                  UUID="${config.uuid}" \
                  "$MNTPOINT";
                trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"; rm -rf "$TEMPDIR";' EXIT;
                SUBVOL_ABS_PATH="$MNTPOINT/${subvolume.name}";
                # Check if it's already a subvolume (using snapshot).
                if ! bcachefs subvolume snapshot "$SUBVOL_ABS_PATH" "$TEMPDIR/" >&2 2>&1; then
                  # It's not a subvolume, now check if it's a directory.
                  if ! test -d "$SUBVOL_ABS_PATH"; then
                    # It's not a subvolume AND not a directory, so create it.
                    mkdir -p -- "$(dirname -- "$SUBVOL_ABS_PATH")";
                    bcachefs subvolume create "$SUBVOL_ABS_PATH";
                  fi
                fi;
              )
            '') (lib.attrValues config.subvolumes)}
          fi;
        ''}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default =
        let
          subvolumeMounts = diskoLib.deepMergeMap (
            subvolume:
            lib.optionalAttrs (subvolume.mountpoint != null) {
              ${subvolume.mountpoint} = ''
                if ! findmnt "${rootMountPoint}${subvolume.mountpoint}" >&2 2>&1; then
                  # @todo Figure out why the "X-mount.mkdir" option here doesn't seem to work,
                  # necessitating running `mkdir` here.
                  mkdir -p "${rootMountPoint}${subvolume.mountpoint}";
                  ${lib.optionalString (
                    config.passwordFile != null
                  ) ''bcachefs unlock -k session "/dev/disk/by-uuid/${config.uuid}" < "${config.passwordFile}";''}
                  bcachefs mount \
                    -o "${
                      lib.concatStringsSep "," (
                        lib.unique (
                          [
                            "X-mount.mkdir"
                            "X-mount.subdir=${lib.removePrefix "/" subvolume.name}"
                          ]
                          ++ subvolume.mountOptions
                        )
                      )
                    }" \
                    UUID="${config.uuid}" \
                    "${rootMountPoint}${subvolume.mountpoint}";
                fi;
              '';
            }
          ) (lib.attrValues config.subvolumes);
        in
        {
          fs =
            subvolumeMounts
            // lib.optionalAttrs (config.mountpoint != null) {
              ${config.mountpoint} = ''
                if ! findmnt "${rootMountPoint}${config.mountpoint}" >&2 2>&1; then
                  # @todo Figure out why the "X-mount.mkdir" option here doesn't seem to work,
                  # necessitating running `mkdir` here.
                  mkdir -p "${rootMountPoint}${config.mountpoint}";
                  ${lib.optionalString (
                    config.passwordFile != null
                  ) ''bcachefs unlock -k session "/dev/disk/by-uuid/${config.uuid}" < "${config.passwordFile}";''}
                  bcachefs mount \
                    -o "${lib.concatStringsSep "," (lib.unique ([ "X-mount.mkdir" ] ++ config.mountOptions))}" \
                    UUID="${config.uuid}" \
                    "${rootMountPoint}${config.mountpoint}";
                fi;
              '';
            };
        };
    };
    _unmount = diskoLib.mkUnmountOption {
      inherit config options;
      default =
        let
          subvolumeMounts = lib.concatMapAttrs (
            _: subvolume:
            lib.optionalAttrs (subvolume.mountpoint != null) {
              ${subvolume.mountpoint} = ''
                if findmnt "UUID=${config.uuid}" "${rootMountPoint}${subvolume.mountpoint}" >&2 2>&1; then
                  umount "${rootMountPoint}${subvolume.mountpoint}";
                fi;
              '';
            }
          ) config.subvolumes;
        in
        {
          fs =
            subvolumeMounts
            // lib.optionalAttrs (config.mountpoint != null) {
              ${config.mountpoint} = ''
                if findmnt "UUID=${config.uuid}" "${rootMountPoint}${config.mountpoint}" >&2 2>&1; then
                  umount "${rootMountPoint}${config.mountpoint}";
                fi;
              '';
            };
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default =
        (lib.optional (config.mountpoint != null) {
          fileSystems.${config.mountpoint} = {
            device = "/dev/disk/by-uuid/${config.uuid}";
            fsType = "bcachefs";
            options = lib.unique ([ "X-mount.mkdir" ] ++ config.mountOptions);
            neededForBoot = true;
          };
        })
        ++ (map (subvolume: {
          fileSystems.${subvolume.mountpoint} = {
            device = "/dev/disk/by-uuid/${config.uuid}";
            fsType = "bcachefs";
            options = lib.unique (
              [
                "X-mount.mkdir"
                "X-mount.subdir=${lib.removePrefix "/" subvolume.name}"
              ]
              ++ subvolume.mountOptions
            );
            neededForBoot = true;
          };
        }) (lib.filter (subvolume: subvolume.mountpoint != null) (lib.attrValues config.subvolumes)));
      description = "NixOS configuration.";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [
        pkgs.bcachefs-tools
        pkgs.util-linux
      ];
      description = "Packages.";
    };
  };
}
