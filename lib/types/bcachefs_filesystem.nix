{
  config,
  diskoLib,
  lib,
  options,
  parent,
  rootMountPoint,
  # @todo Add any other parameters here, if needed
  ...
}: {
  options = {
    # @todo Add any other options here, if needed
    # @todo Check that this implementation is correct:
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Name of the bcachefs filesystem";
    };
    type = lib.mkOption {
      type = lib.types.enum [ "bcachefs_filesystem" ];
      internal = true;
      description = "Type";
    };
    extraFormatArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments passed to the `bcachefs format` command";
    };
    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "defaults" ];
      description = "Options to pass to mount";
    };
    mountpoint = lib.mkOption {
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = "Path to mount the bcachefs filesystem to";
    };
    uuid = lib.mkOption {
      type = lib.types.strMatching "[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}";
      default = let
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
      description = "Path to the file containing the password for encryption";
      example = "/tmp/disk.key";
    };
    # @todo Check that this implementation is correct:
    _parent = lib.mkOption {
      internal = true;
      default = parent;
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      # @todo We need to ensure that the script in `_create` in bcachefs.nix has been ran
      # for each of the devices in the filesystem being created,
      # before the `_create` in this file is ran.
      default = dev: { };
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      # This should set a string variable containing arguments to be passed to the `bcachefs format` command.
      # This string should consist of `--label` and other arguments that correspond to the values of the `label` and `extraFormatArgs` attributes, respectively,
      # from each of the bcachefs devices in this filesystem specified in the configuration.
      # Then, it should set the `default` attribute to a string containing shell commands that calls the `bcachefs format` command, passing in the arguments generated, as well as a `--uuid` value.
      default = ''
        # # Debugging
        # printf "bcachefs_filesystem\n">&2 2>&1;
        # ls -la /dev/disk/by-partlabel/ >&2 2>&1;
        # printf "name: %s\n" "${config.name}" >&2 2>&1;

        if ! test -s "$disko_devices_dir/bcachefs-${config.name}"; then
          printf "\033[31mERROR:\033[0m No devices found for bcachefs filesystem \"${config.name}\"!\nDid you forget to add some or misspell the filesystem name?\n" >&2;
          exit 1;
        fi;
        (
          # Empty out $@
          set --;
          # Collect devices and arguments to $@
          while IFS= read -r line; do
            # Append current line as a new positional parameter
            set -- "$@" "$line";
          done < "$disko_devices_dir/bcachefs-${config.name}";

          # Format the filesystem with all devices and arguments
          if ! blkid -o export "$(blkid -lU ${config.uuid})" | grep -q 'TYPE=bcachefs' >&2 2>&1; then
            bcachefs format \
              "$@" \
              --uuid="${config.uuid}" \
              ${lib.concatStringsSep " \\\n" config.extraFormatArgs} \
              ${lib.optionalString (config.passwordFile != null) ''--encrypted < "${config.passwordFile}"''};
          fi;
        );

        # # Debugging
        # ls -la "$disko_devices_dir";
        # find "$disko_devices_dir" -type f -exec sh -c '
        #   for f do
        #     if file "$f" | grep -q text; then
        #       printf "%s\n" "$f" >&2 2>&1;
        #       cat "$f" >&2 2>&1;
        #       printf "\n" >&2 2>&1;
        #     fi
        #   done
        # ' sh {} +;
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      # @todo Check that this implementation is correct:
      default = lib.optionalAttrs (config.mountpoint != null) {
        dev = ''
        '';
        fs.${config.mountpoint} = ''
          # # Debugging
          # lsblk -f >&2 2>&1;
          # lsblk >&2 2>&1;
          # uname -a >&2 2>&1;
          # bcachefs version >&2 2>&1;

          if ! findmnt "${rootMountPoint}${config.mountpoint}" >&2 2>&1; then
            # @todo Figure out why `X-mount.mkdir` doesn't seem to be working, necessitating `mkdir` here.
            mkdir -p "${rootMountPoint}${config.mountpoint}";
            ${lib.optionalString (config.passwordFile != null) ''bcachefs unlock -k session "/dev/disk/by-uuid/${config.uuid}" < "${config.passwordFile}";''}
            bcachefs mount \
              -o "${lib.concatStringsSep "," (["X-mount.mkdir"] ++ config.mountOptions)}" \
              UUID="${config.uuid}" \
              "${rootMountPoint}${config.mountpoint}";
          fi;

          # # Debugging
          # lsblk -f >&2 2>&1;
          # lsblk >&2 2>&1;
          # mount >&2 2>&1;
        '';
      };
    };
    _unmount = diskoLib.mkUnmountOption {
      inherit config options;
      # @todo Check that this implementation is correct:
      default = lib.optionalAttrs (config.mountpoint != null) {
        fs."${config.mountpoint}" = ''
          umount ${config.mountpoint};
        '';
      };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      # @todo Check that this implementation is correct:
      default = lib.optional (config.mountpoint != null) {
        fileSystems.${config.mountpoint} = {
          device = "UUID=${config.uuid}";
          fsType = "bcachefs";
          options = config.mountOptions;
        };
      };
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [
        pkgs.bcachefs-tools
        # # For debugging
        # pkgs.file
      ];
      description = "Packages";
    };
  };
}