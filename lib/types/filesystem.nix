{ config, options, lib, diskoLib, rootMountPoint, parent, device, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "filesystem" ];
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
      description = "Options to pass to mount";
    };
    mountpoint = lib.mkOption {
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = "Path to mount the filesystem to";
    };
    format = lib.mkOption {
      type = lib.types.str;
      description = "Format of the filesystem";
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
    _update = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        if (blkid -o export ${config.device} | grep -q '^TYPE=${config.format}$'); then
          echo "Filesystem already exists, skipping"
        elif (blkid -o export ${config.device} | grep -q '^TYPE='); then
          echo "Filesystem type mismatch, skipping"
        else
          mkfs.${config.format} \
            ${toString config.extraArgs} \
            ${config.device}
        fi
      '';
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        mkfs.${config.format} \
          ${toString config.extraArgs} \
          ${config.device}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = lib.optionalAttrs (config.mountpoint != null) {
        fs.${config.mountpoint} = ''
          if ! findmnt --source ${config.device} --mountpoint "${rootMountPoint}${config.mountpoint}" >/dev/null 2>&1; then
            mount ${config.device} "${rootMountPoint}${config.mountpoint}" \
              -t "${config.format}" \
              ${lib.concatMapStringsSep " " (opt: "-o ${opt}") config.mountOptions} \
              -o X-mount.mkdir
          fi
        '';
      };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = lib.optional (config.mountpoint != null) {
        fileSystems.${config.mountpoint} = {
          device = config.device;
          fsType = config.format;
          options = config.mountOptions;
        };
      };
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      # type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs:
        [ pkgs.util-linux ] ++ (
          # TODO add many more
          if (config.format == "xfs") then [ pkgs.xfsprogs ]
          else if (config.format == "btrfs") then [ pkgs.btrfs-progs ]
          else if (config.format == "vfat") then [ pkgs.dosfstools ]
          else if (config.format == "ext2") then [ pkgs.e2fsprogs ]
          else if (config.format == "ext3") then [ pkgs.e2fsprogs ]
          else if (config.format == "ext4") then [ pkgs.e2fsprogs ]
          else if (config.format == "bcachefs") then [ pkgs.bcachefs-tools ]
          else [ ]
        );
      description = "Packages";
    };
  };
}
