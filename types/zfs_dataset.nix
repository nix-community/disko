{ config, options, lib, diskoLib, optionTypes, rootMountPoint, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Name of the dataset";
    };
    type = lib.mkOption {
      type = lib.types.enum [ "zfs_dataset" ];
      default = "zfs_dataset";
      internal = true;
      description = "Type";
    };
    zfs_type = lib.mkOption {
      type = lib.types.enum [ "filesystem" "volume" ];
      description = "The type of the dataset";
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

    # filesystem options
    mountpoint = lib.mkOption {
      type = lib.types.nullOr optionTypes.absolute-pathname;
      default = null;
      description = "Path to mount the dataset to";
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
          ${lib.concatStringsSep " " (lib.mapAttrsToList (n: v: "-o ${n}=${v}") config.options)} \
          ${lib.optionalString (config.zfs_type == "volume") "-V ${config.size}"}
        ${lib.optionalString (config.zfs_type == "volume") ''
          udevadm trigger --subsystem-match=block; udevadm settle
          ${lib.optionalString (config.content != null) (config.content._create {dev = "/dev/zvol/${zpool}/${config.name}";})}
        ''}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { zpool }:
        lib.optionalAttrs (config.zfs_type == "volume" && config.content != null) (config.content._mount { dev = "/dev/zvol/${zpool}/${config.name}"; }) //
        lib.optionalAttrs (config.zfs_type == "filesystem" && config.options.mountpoint or "" != "none") {
          fs.${config.mountpoint} = ''
            if ! findmnt ${zpool}/${config.name} "${rootMountPoint}${config.mountpoint}" > /dev/null 2>&1; then
              mount ${zpool}/${config.name} "${rootMountPoint}${config.mountpoint}" \
              -o X-mount.mkdir \
              ${lib.concatMapStringsSep " " (opt: "-o ${opt}") config.mountOptions} \
              ${lib.optionalString ((config.options.mountpoint or "") != "legacy") "-o zfsutil"} \
              -t zfs
            fi
          '';
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = zpool:
        (lib.optional (config.zfs_type == "volume" && config.content != null) (config.content._config "/dev/zvol/${zpool}/${config.name}")) ++
        (lib.optional (config.zfs_type == "filesystem" && config.options.mountpoint or "" != "none") {
          fileSystems.${config.mountpoint} = {
            device = "${zpool}/${config.name}";
            fsType = "zfs";
            options = config.mountOptions ++ lib.optional ((config.options.mountpoint or "") != "legacy") "zfsutil";
          };
        });
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
