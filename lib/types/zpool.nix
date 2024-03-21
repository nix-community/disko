{ config, options, lib, diskoLib, rootMountPoint, ... }:
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
      type = lib.types.enum [
        ""
        "mirror"
        "raidz"
        "raidz2"
        "raidz3"
      ];
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
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = "The mountpoint of the pool";
    };
    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "defaults" ];
      description = "Options to pass to mount";
    };
    datasets = lib.mkOption {
      type = lib.types.attrsOf (diskoLib.subType {
        types = { inherit (diskoLib.types) zfs_fs zfs_volume; };
        extraArgs.parent = config;
      });
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
      default = ''
        readarray -t zfs_devices < <(cat "$disko_devices_dir"/zfs_${config.name})
        if zpool list '${config.name}'; then
          echo "not creating zpool ${config.name} as a pool with that name already exists" >&2
        else
          continue=1
          for dev in "''${zfs_devices[@]}"; do
            if ! blkid "$dev" >/dev/null; then
              # blkid fails, so device seems empty
              :
            elif (blkid "$dev" -o export | grep '^PTUUID='); then
              echo "device $dev already has a partuuid, skipping creating zpool ${config.name}" >&2
              continue=0
            elif (blkid "$dev" -o export | grep '^TYPE=zfs_member'); then
              # zfs_member is a zfs partition, so we try to add the device to the pool
              :
            elif (blkid "$dev" -o export | grep '^TYPE='); then
              echo "device $dev already has a partition, skipping creating zpool ${config.name}" >&2
              continue=0
            fi
          done
          if [ $continue -eq 1 ]; then
            zpool create -f ${config.name} \
              -R ${rootMountPoint} ${config.mode} \
              ${lib.concatStringsSep " " (lib.mapAttrsToList (n: v: "-o ${n}=${v}") config.options)} \
              ${lib.concatStringsSep " " (lib.mapAttrsToList (n: v: "-O ${n}=${v}") config.rootFsOptions)} \
              "''${zfs_devices[@]}"
            if [[ $(zfs get -H mounted ${config.name} | cut -f3) == "yes" ]]; then
              zfs unmount ${config.name}
            fi
          fi
        fi
        ${lib.concatMapStrings (dataset: dataset._create) (lib.attrValues config.datasets)}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default =
        let
          datasetMounts = diskoLib.deepMergeMap (dataset: dataset._mount) (lib.attrValues config.datasets);
        in
        {
          dev = ''
            zpool list '${config.name}' >/dev/null 2>/dev/null ||
              zpool import -l -R ${rootMountPoint} '${config.name}'
            ${lib.concatMapStrings (x: x.dev or "") (lib.attrValues datasetMounts)}
          '';
          fs = datasetMounts.fs or { };
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = map (dataset: dataset._config) (lib.attrValues config.datasets);
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ pkgs.gnugrep pkgs.util-linux ] ++ lib.flatten (map (dataset: dataset._pkgs pkgs) (lib.attrValues config.datasets));
      description = "Packages";
    };
  };

  config = {
    datasets."__root" = {
      _name = config.name;
      _create = "";
      type = "zfs_fs";
      mountpoint = config.mountpoint;
      options = config.rootFsOptions;
    };
  };
}
