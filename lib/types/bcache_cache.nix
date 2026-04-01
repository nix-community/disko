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
      type = lib.types.enum [ "bcache_cache" ];
      internal = true;
      description = "Type";
    };
    device = lib.mkOption {
      type = lib.types.str;
      default = device;
      description = "Device to use as bcache cache.";
    };
    set = lib.mkOption {
      type = lib.types.str;
      description = "Name of the bcache set this cache device belongs to.";
      example = "main";
    };
    bucketSize = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Bucket size for the cache device.";
      example = "512k";
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments passed to `make-bcache -C`.";
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
        echo "${config.device}" >> "$disko_devices_dir/bcache_cache_${lib.escapeShellArg config.set}"
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
