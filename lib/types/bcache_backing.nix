{
  config,
  options,
  lib,
  diskoLib,
  parent,
  device,
  ...
}:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "bcache_backing" ];
      internal = true;
      description = "Type";
    };
    device = lib.mkOption {
      type = lib.types.str;
      default = device;
      description = "Device to use as bcache backing device.";
    };
    set = lib.mkOption {
      type = lib.types.str;
      description = "Name of the bcache set this backing device belongs to.";
      example = "main";
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
        deviceDependencies.bcache.${config.set} = [ dev ];
      };
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        echo "${config.device}" >> "$disko_devices_dir/bcache_backing_${lib.escapeShellArg config.set}"
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { };
    };
    _unmount = diskoLib.mkUnmountOption {
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
      default = pkgs: [ pkgs.bcache-tools ];
      description = "Packages";
    };
  };
}
