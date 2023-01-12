{ config, options, lib, diskoLib, optionTypes, subTypes, rootMountPoint, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Name of the ZFS pool";
    };
    type = lib.mkOption {
      type = lib.types.enum [ "zpool" ];
      default = "zpool";
      internal = true;
      description = "Type";
    };
    mode = lib.mkOption {
      type = lib.types.str; # TODO zfs modes
      default = "";
      description = "Mode of the ZFS pool";
    };
    options = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Options for the ZFS pool";
    };
    rootFsOptions = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Options for the root filesystem";
    };
    mountpoint = lib.mkOption {
      type = lib.types.nullOr optionTypes.absolute-pathname;
      default = null;
      description = "The mountpoint of the pool";
    };
    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "defaults" ];
      description = "Options to pass to mount";
    };
    datasets = lib.mkOption {
      type = lib.types.attrsOf subTypes.zfs_dataset;
      description = "List of datasets to define";
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = diskoLib.jsonType;
      default =
        diskoLib.deepMergeMap (dataset: dataset._meta [ "zpool" config.name ]) (lib.attrValues config.datasets);
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = {}: ''
        zpool create ${config.name} \
          ${config.mode} \
          ${lib.concatStringsSep " " (lib.mapAttrsToList (n: v: "-o ${n}=${v}") config.options)} \
          ${lib.concatStringsSep " " (lib.mapAttrsToList (n: v: "-O ${n}=${v}") config.rootFsOptions)} \
          $(tr '\n' ' ' < "$disko_devices_dir/zfs_${config.name}")
        ${lib.concatMapStrings (dataset: dataset._create {zpool = config.name;}) (lib.attrValues config.datasets)}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = {}:
        let
          datasetMounts = diskoLib.deepMergeMap (dataset: dataset._mount { zpool = config.name; }) (lib.attrValues config.datasets);
        in
        {
          dev = ''
            zpool list '${config.name}' >/dev/null 2>/dev/null || zpool import '${config.name}'
            ${lib.concatMapStrings (x: x.dev or "") (lib.attrValues datasetMounts)}
          '';
          fs = datasetMounts.fs // lib.optionalAttrs (!isNull config.mountpoint) {
            ${config.mountpoint} = ''
              if ! findmnt ${config.name} "${rootMountPoint}${config.mountpoint}" > /dev/null 2>&1; then
                mount ${config.name} "${rootMountPoint}${config.mountpoint}" \
                ${lib.optionalString ((config.options.mountpoint or "") != "legacy") "-o zfsutil"} \
                ${lib.concatMapStringsSep " " (opt: "-o ${opt}") config.mountOptions} \
                -o X-mount.mkdir \
                -t zfs
              fi
            '';
          };
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = [
        (map (dataset: dataset._config config.name) (lib.attrValues config.datasets))
        (lib.optional (!isNull config.mountpoint) {
          fileSystems.${config.mountpoint} = {
            device = config.name;
            fsType = "zfs";
            options = config.mountOptions ++ lib.optional ((config.options.mountpoint or "") != "legacy") "zfsutil";
          };
        })
      ];
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ pkgs.util-linux ] ++ lib.flatten (map (dataset: dataset._pkgs pkgs) (lib.attrValues config.datasets));
      description = "Packages";
    };
  };
}
