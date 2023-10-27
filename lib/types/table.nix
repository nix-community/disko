{ config, options, lib, diskoLib, parent, device, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "table" ];
      internal = true;
      description = "Partition table";
    };
    device = lib.mkOption {
      type = lib.types.str;
      default = device;
      description = "Device to partition";
    };
    format = lib.mkOption {
      type = lib.types.enum [ "gpt" "msdos" ];
      default = "gpt";
      description = "The kind of partition table";
    };
    partitions = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule ({ name, ... }@partition: {
        options = {
          part-type = lib.mkOption {
            type = lib.types.enum [ "primary" "logical" "extended" ];
            default = "primary";
            description = "Partition type";
          };
          fs-type = lib.mkOption {
            type = lib.types.nullOr (lib.types.enum [ "btrfs" "ext2" "ext3" "ext4" "fat16" "fat32" "hfs" "hfs+" "linux-swap" "ntfs" "reiserfs" "udf" "xfs" ]);
            default = null;
            description = "Filesystem type to use";
          };
          name = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "Name of the partition";
          };
          start = lib.mkOption {
            type = lib.types.str;
            default = "0%";
            description = "Start of the partition";
          };
          end = lib.mkOption {
            type = lib.types.str;
            default = "100%";
            description = "End of the partition";
          };
          flags = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Partition flags";
          };
          bootable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether to make the partition bootable";
          };
          content = diskoLib.partitionType { parent = config; device = diskoLib.deviceNumbering config.device partition.config._index; };
          _index = lib.mkOption {
            internal = true;
            default = lib.toInt (lib.head (builtins.match ".*entry ([[:digit:]]+)]" name));
          };
        };
      }));
      default = [ ];
      description = "List of partitions to add to the partition table";
    };
    _parent = lib.mkOption {
      internal = true;
      default = parent;
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = dev:
        lib.foldr lib.recursiveUpdate { } (lib.imap
          (_index: partition:
            lib.optionalAttrs (partition.content != null) (partition.content._meta dev)
          )
          config.partitions);
      description = "Metadata";
    };
    _update = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        if ! sgdisk -d ${config.device}; then
          parted -s ${config.device} -- mklabel ${config.format}
          ${lib.concatStrings (map (partition: ''
            ${lib.optionalString (config.format == "gpt") ''
              parted -s ${config.device} -- mkpart ${partition.name} ${diskoLib.maybeStr partition.fs-type} ${partition.start} ${partition.end}
            ''}
            ${lib.optionalString (config.format == "msdos") ''
              parted -s ${config.device} -- mkpart ${partition.part-type} ${diskoLib.maybeStr partition.fs-type} ${partition.start} ${partition.end}
            ''}
            # ensure /dev/disk/by-path/..-partN exists before continuing
            partprobe ${config.device}
            udevadm trigger --subsystem-match=block
            udevadm settle
            ${lib.optionalString partition.bootable ''
              parted -s ${config.device} -- set ${toString partition._index} boot on
            ''}
            ${lib.concatMapStringsSep "" (flag: ''
              parted -s ${config.device} -- set ${toString partition._index} ${flag} on
            '') partition.flags}
            # ensure further operations can detect new partitions
            partprobe ${config.device}
            udevadm trigger --subsystem-match=block
            udevadm settle
            ${lib.optionalString (partition.content != null) partition.content._create}
          '') config.partitions)}
        else
          echo "Partition table already exists, skipping partition creation"
          ${lib.concatStrings (map (partition: ''
            ${lib.optionalString (partition.content != null) partition.content._update}
          '') config.partitions)}
        fi
      '';
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        parted -s ${config.device} -- mklabel ${config.format}
        ${lib.concatStrings (map (partition: ''
          ${lib.optionalString (config.format == "gpt") ''
            parted -s ${config.device} -- mkpart ${partition.name} ${diskoLib.maybeStr partition.fs-type} ${partition.start} ${partition.end}
          ''}
          ${lib.optionalString (config.format == "msdos") ''
            parted -s ${config.device} -- mkpart ${partition.part-type} ${diskoLib.maybeStr partition.fs-type} ${partition.start} ${partition.end}
          ''}
          # ensure /dev/disk/by-path/..-partN exists before continuing
          partprobe ${config.device}
          udevadm trigger --subsystem-match=block
          udevadm settle
          ${lib.optionalString partition.bootable ''
            parted -s ${config.device} -- set ${toString partition._index} boot on
          ''}
          ${lib.concatMapStringsSep "" (flag: ''
            parted -s ${config.device} -- set ${toString partition._index} ${flag} on
          '') partition.flags}
          # ensure further operations can detect new partitions
          partprobe ${config.device}
          udevadm trigger --subsystem-match=block
          udevadm settle
          ${lib.optionalString (partition.content != null) partition.content._create}
        '') config.partitions)}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default =
        let
          partMounts = lib.foldr lib.recursiveUpdate { } (map
            (partition:
              lib.optionalAttrs (partition.content != null) partition.content._mount
            )
            config.partitions);
        in
        {
          dev = partMounts.dev or "";
          fs = partMounts.fs or { };
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default =
        map
          (partition:
            lib.optional (partition.content != null) partition.content._config
          )
          config.partitions;
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs:
        [
          pkgs.parted
          pkgs.systemdMinimal
          pkgs.gptfdisk
        ] ++ lib.flatten (map
          (partition:
            lib.optional (partition.content != null) (partition.content._pkgs pkgs)
          )
          config.partitions);
      description = "Packages";
    };
  };
}
