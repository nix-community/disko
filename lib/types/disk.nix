{ config, options, lib, diskoLib, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Device name";
    };
    type = lib.mkOption {
      type = lib.types.enum [ "disk" ];
      default = "disk";
      internal = true;
      description = "Type";
    };
    device = lib.mkOption {
      type = diskoLib.optionTypes.absolute-pathname; # TODO check if subpath of /dev ? - No! eg: /.swapfile
      description = "Device path";
    };
    content = diskoLib.deviceType { parent = config; };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = diskoLib.jsonType;
      default =
        lib.optionalAttrs (config.content != null) (config.content._meta [ "disk" config.device ]);
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = _: config.content._create { dev = config.device; };
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = _:
        lib.optionalAttrs (config.content != null) (config.content._mount { dev = config.device; });
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default =
        lib.optional (config.content != null) (config.content._config config.device);
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ pkgs.jq ] ++ lib.optionals (config.content != null) (config.content._pkgs pkgs);
      description = "Packages";
    };
  };
}
