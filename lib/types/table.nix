{ config, options, lib, diskoLib, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "table" ];
      internal = true;
      description = "Partition table";
    };
    format = lib.mkOption {
      type = lib.types.enum [ "gpt" "msdos" ];
      default = "gpt";
      description = "The kind of partition table";
    };
    partitions = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule ({ ... }: {
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
          content = diskoLib.partitionType;
        };
      }));
      default = [ ];
      description = "List of partitions to add to the partition table";
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
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = { dev }: ''
        parted -s ${dev} -- mklabel ${config.format}
        ${lib.concatStrings (lib.imap (index: partition: ''
          ${lib.optionalString (config.format == "gpt") ''
            parted -s ${dev} -- mkpart ${partition.name} ${diskoLib.maybeStr partition.fs-type} ${partition.start} ${partition.end}
          ''}
          ${lib.optionalString (config.format == "msdos") ''
            parted -s ${dev} -- mkpart ${partition.part-type} ${diskoLib.maybeStr partition.fs-type} ${diskoLib.maybeStr partition.fs-type} ${partition.start} ${partition.end}
          ''}
          # ensure /dev/disk/by-path/..-partN exists before continuing
          udevadm trigger --subsystem-match=block; udevadm settle
          ${lib.optionalString partition.bootable ''
            parted -s ${dev} -- set ${toString index} boot on
          ''}
          ${lib.concatMapStringsSep "" (flag: ''
            parted -s ${dev} -- set ${toString index} ${flag} on
          '') partition.flags}
          # ensure further operations can detect new partitions
          udevadm trigger --subsystem-match=block; udevadm settle
          ${lib.optionalString (partition.content != null) (partition.content._create { dev = diskoLib.deviceNumbering dev index; })}
        '') config.partitions)}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { dev }:
        let
          partMounts = lib.foldr lib.recursiveUpdate { } (lib.imap
            (index: partition:
              lib.optionalAttrs (partition.content != null) (partition.content._mount { dev = diskoLib.deviceNumbering dev index; })
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
      default = dev:
        lib.imap
          (index: partition:
            lib.optional (partition.content != null) (partition.content._config (diskoLib.deviceNumbering dev index))
          )
          config.partitions;
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs:
        [ pkgs.parted pkgs.systemdMinimal ] ++ lib.flatten (map
          (partition:
            lib.optional (partition.content != null) (partition.content._pkgs pkgs)
          )
          config.partitions);
      description = "Packages";
    };
  };
}
