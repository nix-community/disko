{ config, options, lib, diskoLib, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "hybrid_partition" ];
      internal = true;
      description = "Type";
    };
    gptPartitionNumber = lib.mkOption {
      type = lib.types.int;
      description = "GPT partition number";
    };
    mbrPartitionType = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "MBR type code";
    };
    mbrBootableFlag = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Set the bootable flag (aka the active flag) on any or all of your hybridized partitions";
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = dev: {};
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = { dev, partNum }: ''
        ${lib.optionalString (config.mbrPartitionType != null) ''
          sfdisk --label-nested dos --part-type ${dev} ${(toString partNum)} ${config.mbrPartitionType}
        ''}
        ${lib.optionalString config.mbrBootableFlag ''
          sfdisk --label-nested dos --activate ${dev} ${(toString partNum)}
        ''}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { dev }: {};
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = dev: {};
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: lib.optionals (config.mbrPartitionType != null) [ pkgs.util-linux ];
      description = "Packages";
    };
  };
}
