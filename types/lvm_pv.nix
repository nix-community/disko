{ config, options, lib, diskoLib, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "lvm_pv" ];
      internal = true;
      description = "Type";
    };
    vg = lib.mkOption {
      type = lib.types.str;
      description = "Volume group";
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = dev: {
        deviceDependencies.lvm_vg.${config.vg} = [ dev ];
      };
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = { dev }: ''
        pvcreate ${dev}
        echo "${dev}" >> $disko_devices_dir/lvm_${config.vg}
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
      default = pkgs: [ pkgs.lvm2 ];
      description = "Packages";
    };
  };
}
