{ config, options, lib, diskoLib, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Name";
    };
    type = lib.mkOption {
      type = lib.types.enum [ "mdadm" ];
      default = "mdadm";
      internal = true;
      description = "Type";
    };
    level = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "mdadm level";
    };
    metadata = lib.mkOption {
      type = lib.types.enum [ "1" "1.0" "1.1" "1.2" "default" "ddf" "imsm" ];
      default = "default";
      description = "Metadata";
    };
    content = diskoLib.deviceType { parent = config; device = "/dev/md/${config.name}"; };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = diskoLib.jsonType;
      default =
        lib.optionalAttrs (config.content != null) (config.content._meta [ "mdadm" config.name ]);
      description = "Metadata";
    };
    _update = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        if ! [ -e /dev/md/${config.name} ]; then
          readarray -t disk_devices < <(cat "$disko_devices_dir"/raid_${config.name})
          echo 'y' | mdadm --create /dev/md/${config.name} \
            --level=${toString config.level} \
            --raid-devices="$(wc -l "$disko_devices_dir"/raid_${config.name} | cut -f 1 -d " ")" \
            --metadata=${config.metadata} \
            --force \
            --homehost=any \
            "''${disk_devices[@]}"
          partprobe /dev/md/${config.name}
          udevadm trigger --subsystem-match=block
          udevadm settle
          # for some reason mdadm devices spawn with an existing partition table, so we need to wipe it
          sgdisk --zap-all /dev/md/${config.name}
          ${lib.optionalString (config.content != null) config.content._update}
        else
          ${lib.optionalString (config.content != null) config.content._update}
        fi
      '';
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        readarray -t disk_devices < <(cat "$disko_devices_dir"/raid_${config.name})
        echo 'y' | mdadm --create /dev/md/${config.name} \
          --level=${toString config.level} \
          --raid-devices="$(wc -l "$disko_devices_dir"/raid_${config.name} | cut -f 1 -d " ")" \
          --metadata=${config.metadata} \
          --force \
          --homehost=any \
          "''${disk_devices[@]}"
        partprobe /dev/md/${config.name}
        udevadm trigger --subsystem-match=block
        udevadm settle
        # for some reason mdadm devices spawn with an existing partition table, so we need to wipe it
        sgdisk --zap-all /dev/md/${config.name}
        ${lib.optionalString (config.content != null) config.content._create}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default =
        lib.optionalAttrs (config.content != null) config.content._mount;
      # TODO we probably need to assemble the mdadm somehow
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default =
        [
          (if lib.versionAtLeast (lib.versions.majorMinor lib.version) "23.11" then {
            boot.swraid.enable = true;
          } else {
            boot.initrd.services.swraid.enable = true;
          })
        ] ++
        lib.optional (config.content != null) config.content._config;
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [
        pkgs.parted # for partprobe
      ] ++ (lib.optionals (config.content != null) (config.content._pkgs pkgs));
      description = "Packages";
    };
  };
}
