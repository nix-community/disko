{ config, options, lib, diskoLib, parent, device, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "zfs" ];
      internal = true;
      description = "Type";
    };
    device = lib.mkOption {
      type = lib.types.str;
      default = device;
      description = "Device";
    };
    pool = lib.mkOption {
      type = lib.types.str;
      description = "Name of the ZFS pool";
    };
    _parent = lib.mkOption {
      internal = true;
      default = parent;
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
    _update = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        echo "${config.device}" >>"$disko_devices_dir"/zfs_${config.pool}
      '';
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        echo "${config.device}" >>"$disko_devices_dir"/zfs_${config.pool}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = [ ];
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
