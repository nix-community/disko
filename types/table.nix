{ config, options, lib, diskoLib, subTypes, ... }:
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
      type = lib.types.listOf subTypes.partition;
      default = [ ];
      description = "List of partitions to add to the partition table";
    };
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
        parted -s ${dev} -- mklabel ${config.format}
        ${lib.concatMapStrings (partition: partition._create {inherit dev; type = config.format;} ) config.partitions}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { dev }:
        let
          partMounts = diskoLib.deepMergeMap (partition: partition._mount { inherit dev; }) config.partitions;
        in
        {
          dev = ''
            ${lib.concatMapStrings (x: x.dev or "") (lib.attrValues partMounts)}
          '';
          fs = partMounts.fs or { };
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = dev:
        map (partition: partition._config dev) config.partitions;
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs:
        [ pkgs.parted pkgs.systemdMinimal ] ++ lib.flatten (map (partition: partition._pkgs pkgs) config.partitions);
      description = "Packages";
    };
  };
}
