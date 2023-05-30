{ config, options, diskoLib, lib, rootMountPoint, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "btrfs" ];
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
      description = "A list of options to pass to mount.";
    };
    subvolumes = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
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
            type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
            default = null;
            description = "Location to mount the subvolume to.";
          };
        };
      }));
      default = { };
      description = "Subvolumes to define for BTRFS.";
    };
    mountpoint = lib.mkOption {
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = "A path to mount the BTRFS filesystem to.";
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
        mkfs.btrfs ${dev} ${toString config.extraArgs}
        ${lib.concatMapStrings (subvol: ''
          MNTPOINT=$(mktemp -d)
          (
            mount ${dev} "$MNTPOINT" -o subvol=/
            trap 'umount $MNTPOINT; rm -rf $MNTPOINT' EXIT
            btrfs subvolume create "$MNTPOINT"/${subvol.name} ${toString subvol.extraArgs}
          )
        '') (lib.attrValues config.subvolumes)}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { dev }:
        let
          subvolMounts = lib.concatMapAttrs
            (_: subvol:
              let
                mountpoint =
                  if (subvol.mountpoint != null) then subvol.mountpoint
                  else if (config.mountpoint == null) then subvol.name
                  else null;
              in
              lib.optionalAttrs (mountpoint != null) {
                fs.${mountpoint} = ''
                  if ! findmnt ${dev} "${rootMountPoint}${mountpoint}" > /dev/null 2>&1; then
                    mount ${dev} "${rootMountPoint}${mountpoint}" \
                    ${lib.concatMapStringsSep " " (opt: "-o ${opt}") (subvol.mountOptions ++ [ "subvol=${subvol.name}" ])} \
                    -o X-mount.mkdir
                  fi
                '';
              }
            )
            config.subvolumes;
        in
        {
          fs = subvolMounts.fs // lib.optionalAttrs (config.mountpoint != null) {
            ${config.mountpoint} = ''
              if ! findmnt ${dev} "${rootMountPoint}${config.mountpoint}" > /dev/null 2>&1; then
                mount ${dev} "${rootMountPoint}${config.mountpoint}" \
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
      default = dev: [
        (map
          (subvol:
            let
              mountpoint =
                if (subvol.mountpoint != null) then subvol.mountpoint
                else if (config.mountpoint == null) then subvol.name
                else null;
            in
            lib.optional (mountpoint != null) {
              fileSystems.${mountpoint} = {
                device = dev;
                fsType = "btrfs";
                options = subvol.mountOptions ++ [ "subvol=${subvol.name}" ];
              };
            }
          )
          (lib.attrValues config.subvolumes))
        (lib.optional (config.mountpoint != null) {
          fileSystems.${config.mountpoint} = {
            device = dev;
            fsType = "btrfs";
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
        [ pkgs.btrfs-progs pkgs.coreutils ];
      description = "Packages";
    };
  };
}
