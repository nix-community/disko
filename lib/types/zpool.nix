{ config, options, lib, diskoLib, rootMountPoint, ... }:
let
  # TODO: Consider expanding to handle `disk` `file` and `draid` mode options.
  modeOptions = [
    ""
    "mirror"
    "raidz"
    "raidz1"
    "raidz2"
    "raidz3"
  ];
in
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
      default = "";
      type = (lib.types.oneOf [
        (lib.types.enum modeOptions)
        (lib.types.attrsOf (diskoLib.subType {
          types = {
            topology =
              let
                vdev = lib.types.submodule ({ ... }: {
                  options = {
                    mode = lib.mkOption {
                      type = lib.types.enum modeOptions;
                      default = "";
                      description = "Mode of the zfs vdev";
                    };
                    members = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      description = "Members of the vdev";
                    };
                  };
                });
              in
              lib.types.submodule
                ({ ... }: {
                  options = {
                    type = lib.mkOption {
                      type = lib.types.enum [ "topology" ];
                      default = "topology";
                      internal = true;
                      description = "Type";
                    };
                    # zfs device types
                    vdev = lib.mkOption {
                      type = lib.types.listOf vdev;
                      default = [ ];
                      description = ''
                        A list of storage vdevs. See
                        https://openzfs.github.io/openzfs-docs/man/master/7/zpoolconcepts.7.html#Virtual_Devices_(vdevs)
                        for details.
                      '';
                      example = [{
                        mode = "mirror";
                        members = [ "x" "y" "/dev/sda1" ];
                      }];
                    };
                    special = lib.mkOption {
                      type = lib.types.nullOr vdev;
                      default = null;
                      description = ''
                        A vdev definition for a special device. See
                        https://openzfs.github.io/openzfs-docs/man/master/7/zpoolconcepts.7.html#special
                        for details.
                      '';
                    };
                    cache = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [ ];
                      description = ''
                        A dedicated zfs cache device (L2ARC). See
                        https://openzfs.github.io/openzfs-docs/man/master/7/zpoolconcepts.7.html#Cache_Devices
                        for details.
                      '';
                    };
                    # TODO: Consider supporting log, spare, and dedup options.
                  };
                });
          };
          extraArgs.parent = config;
        }))
      ]);
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
      default =
        let
          formatOutput = mode: members: ''
            entries+=("${mode}=${
              lib.concatMapStringsSep " "
              (d: if lib.strings.hasPrefix "/" d then d else "/dev/disk/by-partlabel/disk-${d}-zfs") members
            }")
          '';
          formatVdev = vdev: formatOutput vdev.mode vdev.members;
          hasTopology = !(builtins.isString config.mode);
          mode = if hasTopology then "prescribed" else config.mode;
          topology = lib.optionalAttrs hasTopology config.mode.topology;
        in
        ''
          readarray -t zfs_devices < <(cat "$disko_devices_dir/zfs_${config.name}")
          if [ ''${#zfs_devices[@]} -eq 0 ]; then
            echo "no devices found for zpool ${config.name}. Did you misspell the pool name?" >&2
            exit 1
          fi
          # Try importing the pool without mounting anything if it exists.
          # This allows us to set mounpoints.
          if zpool import -N -f "${config.name}" || zpool list "${config.name}"; then
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
              topology=""
              # For shell check
              mode="${mode}"
              if [ "$mode" != "prescribed" ]; then
                topology="${mode} ''${zfs_devices[*]}"
              else
                entries=()
                ${lib.optionalString (hasTopology && topology.vdev != null)
                    (lib.concatMapStrings formatVdev topology.vdev)}
                ${lib.optionalString (hasTopology && topology.special != null)
                    (formatOutput "special ${topology.special.mode}" topology.special.members)}
                ${lib.optionalString (hasTopology && topology.cache != [])
                    (formatOutput "cache" topology.cache)}
                all_devices=()
                for line in "''${entries[@]}"; do
                  # lineformat is mode=device1 device2 device3
                  mode=''${line%%=*}
                  devs=''${line#*=}
                  IFS=' ' read -r -a devices <<< "$devs"
                  all_devices+=("''${devices[@]}")
                  topology+=" ''${mode} ''${devices[*]}"
                done
                # all_devices sorted should equal zfs_devices sorted
                all_devices_list=$(echo "''${all_devices[*]}" | tr ' ' '\n' | sort)
                zfs_devices_list=$(echo "''${zfs_devices[*]}" | tr ' ' '\n' | sort)
                if [[ "$all_devices_list" != "$zfs_devices_list" ]]; then
                  echo "not all disks accounted for, skipping creating zpool ${config.name}" >&2
                  diff  <(echo "$all_devices_list" ) <(echo "$zfs_devices_list") >&2
                  continue=0
                fi
              fi
            fi
            if [ $continue -eq 1 ]; then
              zpool create -f "${config.name}" \
                -R ${rootMountPoint} \
                ${lib.concatStringsSep " " (lib.mapAttrsToList (n: v: "-o ${n}=${v}") config.options)} \
                ${lib.concatStringsSep " " (lib.mapAttrsToList (n: v: "-O ${n}=${v}") config.rootFsOptions)} \
                ''${topology:+ $topology}
              if [[ $(zfs get -H mounted "${config.name}" | cut -f3) == "yes" ]]; then
                zfs unmount "${config.name}"
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
            zpool list "${config.name}" >/dev/null 2>/dev/null ||
              zpool import -l -R ${rootMountPoint} "${config.name}"
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
      _createFilesystem = false;
      type = "zfs_fs";
      mountpoint = config.mountpoint;
      options = config.rootFsOptions;
    };
  };
}
