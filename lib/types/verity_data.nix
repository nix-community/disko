{ config, options, lib, diskoLib, parent, device, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "verity_data" ];
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

    content = diskoLib.deviceType {
      parent = config;
      device = "/dev/mapper/${config.name}";
    };

    _creationTimeContent = (diskoLib.deviceType {
      parent = config;
      device = parent.device;
    }) // {
      internal = true;
      readOnly = true;
      # mhm, does this work?
      default = config.content;
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
        ${lib.optionalString (config._creationTimeContent != null) config._creationTimeContent._create}

        # TODO Can we do this check in nix?
        if "$disko_devices_dir"/verity_volume_data_${lib.escapeShellArg config.verity_volume}; then
          echo "verity_volume_data_${lib.escapeShellArg config.vg} already exists. You can only assign one data device to a verity volume." >&2
          exit 1
        fi
        echo "${config.device}" > "$disko_devices_dir"/verity_volume_data_${lib.escapeShellArg config.verity_volume}
      '';
    };

    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = let
        contentMount = config.content._mount;
      in {
        fs = lib.optionalAttrs (config.creationTimeContent != null) contentMount.fs or { };
      };
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
