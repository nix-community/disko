{ config, options, diskoLib, lib, rootMountPoint, parent, device, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "bcachefs" ];
      internal = true;
      description = "Type";
    };
    device = lib.mkOption {
      type = lib.types.str;
      default = device;
      description = "Device to use";
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments";
    };
    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "defaults" ];
      description = "A list of options to pass to mount.";
    };
    subvolumes = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            default = config._module.args.name;
            description = "Name of the Bcachefs subvolume.";
          };
        };
      }));
      default = { };
      description = "Subvolumes to define for Bcachefs.";
    };
    mountpoint = lib.mkOption {
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = "A path to mount the Bcachefs filesystem to.";
    };
    _parent = lib.mkOption {
      internal = true;
      default = parent;
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = _dev: { };
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        modprobe bcachefs
        mkfs.bcachefs ${toString config.extraArgs} ${config.device}
        ${lib.concatMapStrings (subvol: ''
          (
            MNTPOINT=$(mktemp -d)
            mount ${config.device} "$MNTPOINT"
            trap 'umount $MNTPOINT; rm -rf $MNTPOINT' EXIT
            echo "creating subvol ${subvol.name}"
            bcachefs subvolume create "$MNTPOINT"/${subvol.name}
          )
        '') (lib.attrValues config.subvolumes)}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default =
        {
          fs = lib.optionalAttrs (config.mountpoint != null) {
            ${config.mountpoint} = ''
              if ! findmnt ${config.device} "${rootMountPoint}${config.mountpoint}" > /dev/null 2>&1; then
                mount ${config.device} "${rootMountPoint}${config.mountpoint}" \
                ${lib.concatMapStringsSep " " (opt: "-o ${opt}") config.mountOptions} \
                -o X-mount.mkdir
              fi
            '';
          };
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = [
       (lib.optional (config.mountpoint != null) {
          fileSystems.${config.mountpoint} = {
            device = config.device;
            fsType = "bcachefs";
            options = config.mountOptions;
          };
        })
      ];
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs:
        [ pkgs.bcachefs-tools pkgs.coreutils ];
      description = "Packages";
    };
  };
}
