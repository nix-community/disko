{ config, options, diskoLib, lib, rootMountPoint, parent, device, ... }:
let
  swapFileType = lib.types.submodule ({ config, name, ... }: {
    options = {
      # Note: this is by-default enabled, as it will be created by
      # doing `swap.file.foo.size = "2G";` for instance. The reason
      # for having this enable option is so that it can be disabled
      # in separate modules from where the swap is defined.
      enable = lib.mkOption {
        default = true;
        example = true;
        description = "Whether to enable swapfile '${name}'.";
        type = lib.types.bool;
      };

      size = lib.mkOption {
        type = lib.types.strMatching "^([0-9]+[KMGTP])?$";
        description = "Size of the swap file (e.g. 2G)";
      };

      path = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Path to the swap file (relative to the mountpoint)";
      };
    };
  });

  swapType = lib.types.submodule ({ config, ... }: {
    options = {
      file = lib.mkOption {
        type = lib.types.attrsOf swapFileType;
        default = { };
        description = "Swap files";
      };
    };
  });

  enabledSwaps = swap:
    lib.filter (file: file.enable) (lib.attrValues swap.file);

  swapConfig = { mountpoint, swap }:
    let files = enabledSwaps swap;
    in
    lib.optional (lib.length files != 0) {
      swapDevices = builtins.map
        (file: {
          device = "${mountpoint}/${file.path}";
        })
        files;
    };

  swapCreate = mountpoint: swap:
    let files = enabledSwaps swap;
    in
    lib.concatMapStringsSep
      "\n"
      (file: ''btrfs filesystem mkswapfile --size ${file.size} "${mountpoint}/${file.path}"'')
      files;

  partitionSwapCreate = device: swap:
    let files = enabledSwaps swap;
    in
    lib.optionalString
      (lib.length files != 0)
      ''
        (
          MNTPOINT=$(mktemp -d)
          mount ${device} "$MNTPOINT" -o subvol=/
          trap 'umount $MNTPOINT; rm -rf $MNTPOINT' EXIT
          ${swapCreate "$MNTPOINT" swap}
        )
      '';
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
            ${swapCreate "$MNTPOINT/${subvol.name}" subvol.swap}
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
