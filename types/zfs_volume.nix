{ config, options, lib, diskoLib, optionTypes, rootMountPoint, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Name of the dataset";
    };
    type = lib.mkOption {
      type = lib.types.enum [ "zfs_volume" ];
      default = "zfs_volume";
      internal = true;
      description = "Type";
    };
    options = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Options to set for the dataset";
    };
    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "defaults" ];
      description = "Mount options";
    };

    # volume options
    size = lib.mkOption {
      type = lib.types.nullOr lib.types.str; # TODO size
      default = null;
      description = "Size of the dataset";
    };

    content = diskoLib.partitionType;

    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = dev:
        lib.optionalAttrs (config.content != null) (config.content._meta dev);
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = { zpool }: ''
        zfs create ${zpool}/${config.name} \
          ${lib.concatStringsSep " " (lib.mapAttrsToList (n: v: "-o ${n}=${v}") config.options)} -V ${config.size}
        udevadm trigger --subsystem-match=block; udevadm settle
        ${lib.optionalString (config.content != null) (config.content._create {dev = "/dev/zvol/${zpool}/${config.name}";})}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { zpool }:
        lib.optionalAttrs (config.content != null) (config.content._mount { dev = "/dev/zvol/${zpool}/${config.name}"; });
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = zpool:
        lib.optional (config.content != null) (config.content._config "/dev/zvol/${zpool}/${config.name}");
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ pkgs.util-linux ] ++ lib.optionals (config.content != null) (config.content._pkgs pkgs);
      description = "Packages";
    };
  };
}

