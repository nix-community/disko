{ config, options, lib, diskoLib, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Name";
    };

    type = lib.mkOption {
      type = lib.types.enum [ "bcachefspool" ];
      default = "bcachefspool";
      internal = true;
      description = "Type";
    };

    formatOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "defaults" ];
      description = "Format options";
    };

    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "defaults" ];
      description = "Mount options";
    };

    mountpoint = lib.mkOption {
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = "A path to mount the bcachefs filesystem to.";
    };

    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = diskoLib.jsonType;
      default =
        lib.optionalAttrs (config.content != null) (config.content._meta [ "bcachefspool" config.name ]);
      description = "Metadata";
    };

    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        readarray -t bcachefs_devices < <(cat "$disko_devices_dir"/bcachefs_${config.name}/devices)
        readarray -t bcachefs_labels < <(cat "$disko_devices_dir"/bcachefs_${config.name}/labels)
        readarray -t bcachefs_format_options < <(cat "$disko_devices_dir"/bcachefs_${config.name}/format_options)

        device_configs=()

        for ((i=0; i<''${#bcachefs_devices[@]}; i++)); do
            device=''${bcachefs_devices[$i]}
            label=''${bcachefs_labels[$i]}
            format_options=''${bcachefs_format_options[$i]}
            device_configs+=("--label=$label $format_options $device")
        done

        bcachefs format --fs_label=${config.name} ${lib.concatStringsSep " " config.formatOptions} \
          $(IFS=' \' ; echo "''${device_configs[*]}")
      '';
    };

    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = "TODO";
    };

    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = lib.optional (config.options.mountpoint or "" != "none") {
          fileSystems.${config.mountpoint} = {
            device = "${lib.concatStringsSep ":" config.formatOptions}";
            fsType = "bcachefs";
            options = config.mountOptions;
          };
        };
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [];
      description = "Packages";
    };
  };
}
