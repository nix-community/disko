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
    content = diskoLib.deviceType { parent = config; };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = diskoLib.jsonType;
      default =
        lib.optionalAttrs (config.content != null) (config.content._meta [ "mdadm" config.name ]);
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = _: ''
        readarray -t disk_devices < <(cat "$disko_devices_dir"/raid_${config.name})
        echo 'y' | mdadm --create /dev/md/${config.name} \
          --level=${toString config.level} \
          --raid-devices="$(wc -l "$disko_devices_dir"/raid_${config.name} | cut -f 1 -d " ")" \
          --metadata=${config.metadata} \
          --force \
          --homehost=any \
          "''${disk_devices[@]}"
        udevadm trigger --subsystem-match=block; udevadm settle
        ${lib.optionalString (config.content != null) (config.content._create {dev = "/dev/md/${config.name}";})}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = _:
        lib.optionalAttrs (config.content != null) (config.content._mount { dev = "/dev/md/${config.name}"; });
      # TODO we probably need to assemble the mdadm somehow
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default =
        lib.optional (config.content != null) (config.content._config "/dev/md/${config.name}");
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: (lib.optionals (config.content != null) (config.content._pkgs pkgs));
      description = "Packages";
    };
  };
}
