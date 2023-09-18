{ config, options, diskoLib, lib, rootMountPoint, parent, device, ... }:
let
  swapFileType = lib.types.submodule ({ config, ... }: {
    options = {
      size = lib.mkOption {
        type = lib.types.strMatching "^([0-9]+[KMGTP])?$";
        description = "Size of the swap file (e.g. 2G)";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "swapfile";
        description = "Prefix for the swap file";
      };

      path = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to the swap file (relative to the mountpoint) - gets the index as an argument, starting at 1";
      };

      _path = lib.mkOption {
        internal = true;
        type = lib.types.functionTo lib.types.str;
        default = idx:
          if config.path != null
          then config.path
          else "${config.pathPrefix}${lib.optionalString (idx != 1) (toString idx)}";
      };
    };
  });

  swapType = lib.types.submodule ({ config, ... }: {
    options = {
      enable = lib.mkEnableOption "swap";

      files = lib.mkOption {
        type = lib.types.listOf swapFileType;
        default = [ ];
        description = "Swap files";
      };
    };
  });

  swapConfig = { mountpoint, swap }: lib.optional swap.enable {
    swapDevices = lib.imap1
      (idx: file: {
        device = "${mountpoint}/${file._path idx}";
      })
      swap.files;
  };

  subvolSwapCreate = mountpoint: swap:
    lib.optionalString
      swap.enable
      (
        lib.concatImapStringsSep "\n"
          (idx: file:
            ''btrfs filesystem mkswapfile --size ${file.size} ${mountpoint}/${file._path idx}''
          )
          swap.files
      );

  partitionSwapCreate = device: swap:
    lib.optionalString
      swap.enable
      (
        lib.concatImapStringsSep "\n"
          (idx: file:
            ''
              (
                MNTPOINT=$(mktemp -d)
                mount ${device} "$MNTPOINT" -o subvol=/
                trap 'umount $MNTPOINT; rm -rf $MNTPOINT' EXIT
                btrfs filesystem mkswapfile --size ${file.size} "$MNTPOINT"/${file._path idx}
              )
            ''
          )
          swap.files
      );
in
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "btrfs" ];
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
          swap = lib.mkOption {
            type = swapType;
            default = { };
            description = "Swap file configuration";
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
    swap = lib.mkOption {
      type = swapType;
      default = { };
      description = "Swap file configuration";
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
      default = ''
        mkfs.btrfs ${config.device} ${toString config.extraArgs}
        ${partitionSwapCreate config.device config.swap}
        ${lib.concatMapStrings (subvol: ''
          (
            MNTPOINT=$(mktemp -d)
            mount ${config.device} "$MNTPOINT" -o subvol=/
            trap 'umount $MNTPOINT; rm -rf $MNTPOINT' EXIT
            btrfs subvolume create "$MNTPOINT"/${subvol.name} ${toString subvol.extraArgs}
            ${subvolSwapCreate ''"$MNTPOINT"/${subvol.name}'' subvol.swap}
          )
        '') (lib.attrValues config.subvolumes)}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default =
        let
          subvolMounts = lib.concatMapAttrs
            (_: subvol:
              lib.warnIf (subvol.mountOptions != (options.subvolumes.type.getSubOptions [ ]).mountOptions.default && subvol.mountpoint == null)
                "Subvolume ${subvol.name} has mountOptions but no mountpoint. See upgrade guide (2023-07-09 121df48)."
                lib.optionalAttrs
                (subvol.mountpoint != null)
                {
                  ${subvol.mountpoint} = ''
                    if ! findmnt ${config.device} "${rootMountPoint}${subvol.mountpoint}" > /dev/null 2>&1; then
                      mount ${config.device} "${rootMountPoint}${subvol.mountpoint}" \
                      ${lib.concatMapStringsSep " " (opt: "-o ${opt}") (subvol.mountOptions ++ [ "subvol=${subvol.name}" ])} \
                      -o X-mount.mkdir
                    fi
                  '';
                }
            )
            config.subvolumes;
        in
        {
          fs = subvolMounts // lib.optionalAttrs (config.mountpoint != null) {
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
        (map
          (subvol:
            lib.optional (subvol.mountpoint != null) {
              fileSystems.${subvol.mountpoint} = {
                device = config.device;
                fsType = "btrfs";
                options = subvol.mountOptions ++ [ "subvol=${subvol.name}" ];
              };
            }
          )
          (lib.attrValues config.subvolumes))
        (lib.optional (config.mountpoint != null) {
          fileSystems.${config.mountpoint} = {
            device = config.device;
            fsType = "btrfs";
            options = config.mountOptions;
          };
        })
        (map
          (subvol: swapConfig {
            inherit (subvol) mountpoint swap;
          })
          (lib.attrValues config.subvolumes))
        (swapConfig {
          inherit (config) mountpoint swap;
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
