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
    content = diskoLib.deviceType;
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = diskoLib.jsonType;
      default =
        lib.optionalAttrs (!isNull config.content) (config.content._meta [ "mdadm" config.name ]);
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = {}: ''
        echo 'y' | mdadm --create /dev/md/${config.name} \
          --level=${toString config.level} \
          --raid-devices=$(wc -l $disko_devices_dir/raid_${config.name} | cut -f 1 -d " ") \
          --metadata=${config.metadata} \
          --force \
          --homehost=any \
          $(tr '\n' ' ' < $disko_devices_dir/raid_${config.name})
        udevadm trigger --subsystem-match=block; udevadm settle
        ${lib.optionalString (!isNull config.content) (config.content._create {dev = "/dev/md/${config.name}";})}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = {}:
        lib.optionalAttrs (!isNull config.content) (config.content._mount { dev = "/dev/md/${config.name}"; });
      # TODO we probably need to assemble the mdadm somehow
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default =
        lib.optional (!isNull config.content) (config.content._config "/dev/md/${config.name}");
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: (lib.optionals (!isNull config.content) (config.content._pkgs pkgs));
      description = "Packages";
    };
  };
}
