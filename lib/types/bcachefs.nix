{ config, options, lib, diskoLib, parent, device, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "bcachefs" ];
      internal = true;
      description = "Type";
    };
    device = lib.mkOption {
      type = lib.types.str;
      description = "Device";
      default = device;
    };

    pool = lib.mkOption {
      type = lib.types.str;
      description = "Pool";
    };

    label = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Label";
    };

    formatArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Formating Arguments";
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
        deviceDependencies.bcachefspool.${config.pool} = [ dev ];
      };
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        echo ${config.device} >>"$disko_devices_dir"/bcachefs_${config.pool}/devices
        echo ${config.label} >>"$disko_devices_dir"/bcachefs_${config.pool}/labels
        echo ${lib.concatStringsSep " " config.formatArgs} >>"$disko_devices_dir"/bcachefs_${config.pool}/format_args
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = [
        {
          disko.devices._internal.bcachefspools.${config.pool} = [ (lib.traceVal config.device) ];
        }
      ];
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ pkgs.bcachefs-tools ];
      description = "Packages";
    };
  };
}
