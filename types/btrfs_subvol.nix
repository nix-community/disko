{ config, options, diskoLib, lib, optionTypes, rootMountPoint, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Name of the BTRFS subvolume.";
    };
    type = lib.mkOption {
      type = lib.types.enum [ "btrfs_subvol" ];
      default = "btrfs_subvol";
      internal = true;
      description = "Type";
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments";
    };
    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "defaults" ];
      description = "Options to pass to mount";
    };
    mountpoint = lib.mkOption {
      type = lib.types.nullOr optionTypes.absolute-pathname;
      default = null;
      description = "Location to mount the subvolume to.";
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
      default = { dev }: ''
        MNTPOINT=$(mktemp -d)
        (
          mount ${dev} "$MNTPOINT" -o subvol=/
          trap 'umount $MNTPOINT; rm -rf $MNTPOINT' EXIT
          btrfs subvolume create "$MNTPOINT"/${config.name} ${toString config.extraArgs}
        )
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { dev, parent }:
        let
          mountpoint =
            if (config.mountpoint != null) then config.mountpoint
            else if (parent == null) then config.name
            else null;
        in
        lib.optionalAttrs (mountpoint != null) {
          fs.${mountpoint} = ''
            if ! findmnt ${dev} "${rootMountPoint}${mountpoint}" > /dev/null 2>&1; then
              mount ${dev} "${rootMountPoint}${mountpoint}" \
              ${lib.concatMapStringsSep " " (opt: "-o ${opt}") (config.mountOptions ++ [ "subvol=${config.name}" ])} \
              -o X-mount.mkdir
            fi
          '';
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = dev: parent:
        let
          mountpoint =
            if (config.mountpoint != null) then config.mountpoint
            else if (parent == null) then config.name
            else null;
        in
        lib.optional (mountpoint != null) {
          fileSystems.${mountpoint} = {
            device = dev;
            fsType = "btrfs";
            options = config.mountOptions ++ [ "subvol=${config.name}" ];
          };
        };
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ pkgs.coreutils ];
      description = "Packages";
    };
  };
}
