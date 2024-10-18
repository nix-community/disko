{ config, options, lib, diskoLib, parent, ... }:
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

    content = diskoLib.partitionType { parent = config; device = "/dev/zvol/${config._parent.name}/${config.name}"; };

    _parent = lib.mkOption {
      internal = true;
      default = parent;
    };
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
      default = ''
        if ! zfs get type "${config._parent.name}/${config.name}" >/dev/null 2>&1; then
          zfs create "${config._parent.name}/${config.name}" \
            ${lib.concatStringsSep " " (lib.mapAttrsToList (n: v: "-o ${n}=${v}") config.options)} \
            -V ${config.size}
          zvol_wait
          partprobe "/dev/zvol/${config._parent.name}/${config.name}"
          udevadm trigger --subsystem-match=block
          udevadm settle
        fi
        ${lib.optionalString (config.content != null) config.content._create}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default =
        lib.optionalAttrs (config.content != null) config.content._mount;
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default =
        lib.optional (config.content != null) config.content._config;
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [
        pkgs.util-linux
        pkgs.parted # for partprobe
      ] ++ lib.optionals (config.content != null) (config.content._pkgs pkgs);
      description = "Packages";
    };
  };
}

