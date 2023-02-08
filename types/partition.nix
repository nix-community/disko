{ config, options, lib, diskoLib, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "partition" ];
      internal = true;
      description = "Type";
    };
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
    index = lib.mkOption {
      type = lib.types.int;
      # TODO find a better way to get the index
      default = lib.toInt (lib.head (builtins.match ".*entry ([[:digit:]]+)]" config._module.args.name));
      description = "Index of the partition";
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
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = dev:
        lib.optionalAttrs (config.content != null) (config.content._meta dev);
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = { dev, type }: ''
        ${lib.optionalString (type == "gpt") ''
          parted -s ${dev} -- mkpart ${config.name} ${diskoLib.maybeStr config.fs-type} ${config.start} ${config.end}
        ''}
        ${lib.optionalString (type == "msdos") ''
          parted -s ${dev} -- mkpart ${config.part-type} ${diskoLib.maybeStr config.fs-type} ${diskoLib.maybeStr config.fs-type} ${config.start} ${config.end}
        ''}
        # ensure /dev/disk/by-path/..-partN exists before continuing
        udevadm trigger --subsystem-match=block; udevadm settle
        ${lib.optionalString config.bootable ''
          parted -s ${dev} -- set ${toString config.index} boot on
        ''}
        ${lib.concatMapStringsSep "" (flag: ''
          parted -s ${dev} -- set ${toString config.index} ${flag} on
        '') config.flags}
        # ensure further operations can detect new partitions
        udevadm trigger --subsystem-match=block; udevadm settle
        ${lib.optionalString (config.content != null) (config.content._create {dev = diskoLib.deviceNumbering dev config.index;})}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { dev }:
        lib.optionalAttrs (config.content != null) (config.content._mount { dev = diskoLib.deviceNumbering dev config.index; });
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = dev:
        lib.optional (config.content != null) (config.content._config (diskoLib.deviceNumbering dev config.index));
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: lib.optionals (config.content != null) (config.content._pkgs pkgs);
      description = "Packages";
    };
  };
}
