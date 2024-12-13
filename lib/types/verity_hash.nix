{ config, options, lib, diskoLib, parent, device, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "verity_hash" ];
      internal = true;
      description = "Type";
    };
    device = lib.mkOption {
      type = lib.types.str;
      description = "Device";
      default = device;
    };
    verity_volume = lib.mkOption {
      type = lib.types.str;
      description = "The name of the verity volume";
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
        deviceDependencies.verity_volume.${config.verity_volume} = [ dev ];
      };
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        if [[ -f "$disko_devices_dir"/verity_volume__${lib.escapeShellArg config.verity_volume} ]]; then
          echo "verity_volume_hash_${lib.escapeShellArg config.vg} already exists. You can only assign one hash device to a verity volume." >&2
          exit 1
        fi
        echo "${config.device}" > "$disko_devices_dir"/verity_volume_hash_${lib.escapeShellArg config.verity_volume}
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
      default = pkgs: [ ];
      description = "Packages";
    };
  };
}
