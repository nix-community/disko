{ config, options, lib, diskoLib, subTypes, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "hybrid_table" ];
      internal = true;
      description = "Hybrid MBR/GPT Partition table";
    };
    efiGptPartitionFirst = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Place EFI GPT (0xEE) partition first in MBR (good for GRUB)";
    };
    hybrid_partitions = lib.mkOption {
      type = lib.types.listOf subTypes.hybrid_partition;
      default = [ ];
      description = "List of one to three GPT partitions to be added to the hybrid MBR";
    };
    content = diskoLib.deviceType;
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = dev:
        diskoLib.deepMergeMap (partition: partition._meta dev) config.partitions;
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = { dev }: ''
        ${(config.content._create { inherit dev; })}

        sgdisk -h \
          ${lib.concatMapStringsSep ":" (hp: (toString hp.gptPartitionNumber)) config.hybrid_partitions}${lib.optionalString (!config.efiGptPartitionFirst) ":EE"} \
          ${dev}

        ${lib.concatImapStrings (i: hp: hp._create {inherit dev; partNum = i + (if config.efiGptPartitionFirst then 1 else 0 );}) config.hybrid_partitions}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { dev }: config.content._mount { inherit dev; };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = dev: config.content._config dev;
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs:
        [ pkgs.gptfdisk ] ++ (config.content._pkgs pkgs);
      description = "Packages";
    };
  };
}
