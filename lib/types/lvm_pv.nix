{ config, options, lib, diskoLib, parent, device, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "lvm_pv" ];
      internal = true;
      description = "Type";
    };
    device = lib.mkOption {
      type = lib.types.str;
      description = "Device";
      default = device;
    };
    vg = lib.mkOption {
      type = lib.types.str;
      description = "Volume group";
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
        deviceDependencies.lvm_vg.${config.vg} = [ dev ];
      };
      description = "Metadata";
    };
    _update = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        if ! (blkid ${config.device} -o export | grep -q '^TYPE=LVM2_member$'); then
          pvcreate ${config.device}
          echo "${config.device}" >>"$disko_devices_dir"/lvm_${config.vg}
        else
          echo "Device ${config.device} is already a PV"
          echo "${config.device}" >>"$disko_devices_dir"/lvm_${config.vg}
        fi
      '';
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        pvcreate ${config.device}
        echo "${config.device}" >>"$disko_devices_dir"/lvm_${config.vg}
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
      default = pkgs: [ pkgs.lvm2 ];
      description = "Packages";
    };
  };
}
