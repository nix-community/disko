{ config, options, lib, diskoLib, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "zfs" ];
      internal = true;
      description = "Type";
    };
    pool = lib.mkOption {
      type = lib.types.str;
      description = "Name of the ZFS pool";
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = dev: {
        deviceDependencies.zpool.${config.pool} = [ dev ];
      };
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = { dev }: ''
        echo "${dev}" >> $disko_devices_dir/zfs_${config.pool}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { dev }:
        { };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = dev: [ ];
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ pkgs.zfs ];
      description = "Packages";
    };
  };
}
