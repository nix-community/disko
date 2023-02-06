{ lib, rootMountPoint }:
with lib;
with builtins;

rec {

  diskoLib = {
    # like lib.types.oneOf but instead of a list takes an attrset
    # uses the field "type" to find the correct type in the attrset
    subType = typeAttr: lib.mkOptionType rec {
      name = "subType";
      description = "one of ${concatStringsSep "," (attrNames typeAttr)}";
      check = x: if x ? type then typeAttr.${x.type}.check x else throw "No type option set in:\n${generators.toPretty {} x}";
      merge = loc: foldl' (res: def: typeAttr.${def.value.type}.merge loc [ def ]) { };
      nestedTypes = typeAttr;
    };

    # option for valid contents of partitions (basically like devices, but without tables)
    partitionType = lib.mkOption {
      type = lib.types.nullOr (diskoLib.subType { inherit (subTypes) btrfs filesystem zfs mdraid luks lvm_pv swap; });
      default = null;
      description = "The type of partition";
    };

    # option for valid contents of devices
    deviceType = lib.mkOption {
      type = lib.types.nullOr (diskoLib.subType { inherit (subTypes) table btrfs filesystem zfs mdraid luks lvm_pv swap; });
      default = null;
      description = "The type of device";
    };

    /* deepMergeMap takes a function and a list of attrsets and deep merges them

       deepMergeMap :: -> (AttrSet -> AttrSet ) -> [ AttrSet ] -> Attrset

       Example:
         deepMergeMap (x: x.t = "test") [ { x = { y = 1; z = 3; }; } { x = { bla = 234; }; } ]
         => { x = { y = 1; z = 3; bla = 234; t = "test"; }; }
    */
    deepMergeMap = f: foldr (attr: acc: (recursiveUpdate acc (f attr))) { };

    /* get a device and an index to get the matching device name

       deviceNumbering :: str -> int -> str

       Example:
       deviceNumbering "/dev/sda" 3
       => "/dev/sda3"

       deviceNumbering "/dev/disk/by-id/xxx" 2
       => "/dev/disk/by-id/xxx-part2"
    */
    deviceNumbering = dev: index:
      if match "/dev/[vs]d.+" dev != null then
        dev + toString index  # /dev/{s,v}da style
      else if match "/dev/(disk|zvol)/.+" dev != null then
        "${dev}-part${toString index}" # /dev/disk/by-id/xxx style, also used by zfs's zvolumes
      else if match "/dev/(nvme|md/|mmcblk).+" dev != null then
        "${dev}p${toString index}" # /dev/nvme0n1p1 style
      else
        abort ''
          ${dev} seems not to be a supported disk format. Please add this to disko in https://github.com/nix-community/disko/blob/master/types/default.nix
        '';

    /* A nix option type representing a json datastructure, vendored from nixpkgs to avoid dependency on pkgs */
    jsonType =
      let
        valueType = lib.types.nullOr
          (lib.types.oneOf [
            lib.types.bool
            lib.types.int
            lib.types.float
            lib.types.str
            lib.types.path
            (lib.types.attrsOf valueType)
            (lib.types.listOf valueType)
          ]) // {
          description = "JSON value";
        };
      in
      valueType;

    /* Given a attrset of deviceDependencies and a devices attrset
       returns a sorted list by deviceDependencies. aborts if a loop is found

       sortDevicesByDependencies :: AttrSet -> AttrSet -> [ [ str str ] ]
    */
    sortDevicesByDependencies = deviceDependencies: devices:
      let
        dependsOn = a: b:
          elem a (attrByPath b [ ] deviceDependencies);
        maybeSortedDevices = toposort dependsOn (diskoLib.deviceList devices);
      in
      if (hasAttr "cycle" maybeSortedDevices) then
        abort "detected a cycle in your disk setup: ${maybeSortedDevices.cycle}"
      else
        maybeSortedDevices.result;

    /* Takes a devices attrSet and returns it as a list

       deviceList :: AttrSet -> [ [ str str ] ]

       Example:
         deviceList { zfs.pool1 = {}; zfs.pool2 = {}; mdadm.raid1 = {}; }
         => [ [ "zfs" "pool1" ] [ "zfs" "pool2" ] [ "mdadm" "raid1" ] ]
    */
    deviceList = devices:
      concatLists (mapAttrsToList (n: v: (map (x: [ n x ]) (attrNames v))) devices);

    /* Takes either a string or null and returns the string or an empty string

       maybeStr :: Either (str null) -> str

       Example:
         maybeStr null
         => ""
         maybeSTr "hello world"
         => "hello world"
    */
    maybeStr = x: optionalString (x != null) x;

    /* Takes a Submodules config and options argument and returns a serializable
       subset of config variables as a shell script snippet.
    */
    defineHookVariables = { config, options }:
      let
        sanitizeName = lib.replaceStrings [ "-" ] [ "_" ];
        isAttrsOfSubmodule = o: o.type.name == "attrsOf" && o.type.nestedTypes.elemType.name == "submodule";
        isSerializable = n: o: !(
          lib.hasPrefix "_" n
          || lib.hasSuffix "Hook" n
          || isAttrsOfSubmodule o
          # TODO don't hardcode diskoLib.subType options.
          || n == "content" || n == "partitions"
        );
      in
      lib.toShellVars
        (lib.mapAttrs'
          (n: o: lib.nameValuePair (sanitizeName n) o.value)
          (lib.filterAttrs isSerializable options));

    mkHook = description: lib.mkOption {
      inherit description;
      type = lib.types.str;
      default = "";
    };

    mkSubType = module: lib.types.submodule [
      module

      {
        options = {
          preCreateHook = diskoLib.mkHook "shell commands to run before create";
          postCreateHook = diskoLib.mkHook "shell commands to run after create";
          preMountHook = diskoLib.mkHook "shell commands to run before mount";
          postMountHook = diskoLib.mkHook "shell commands to run after mount";
        };
        config._module.args = {
          inherit diskoLib optionTypes subTypes rootMountPoint;
        };
      }
    ];

    mkCreateOption = { config, options, default }@attrs:
      lib.mkOption {
        internal = true;
        readOnly = true;
        type = lib.types.functionTo lib.types.str;
        default = args:
          let
            name = "format";
            test = lib.optionalString (config ? name) "${config.${name}}";
          in
          ''
            ( # ${config.type} ${concatMapStringsSep " " (n: toString (config.${n} or "")) ["name" "device" "format" "mountpoint"]}
              ${diskoLib.defineHookVariables { inherit config options; }}
              ${config.preCreateHook}
              ${attrs.default args}
              ${config.postCreateHook}
            )
          '';
        description = "Creation script";
      };

    mkMountOption = { config, options, default }@attrs:
      lib.mkOption {
        internal = true;
        readOnly = true;
        type = lib.types.functionTo diskoLib.jsonType;
        inherit (attrs) default;
        description = "Mount script";
      };


    /* Takes a disko device specification, returns an attrset with metadata

       meta :: lib.types.devices -> AttrSet
    */
    meta = devices: diskoLib.deepMergeMap (dev: dev._meta) (flatten (map attrValues (attrValues devices)));

    /* Takes a disko device specification and returns a string which formats the disks

       create :: lib.types.devices -> str
    */
    create = devices:
      let
        sortedDeviceList = diskoLib.sortDevicesByDependencies ((diskoLib.meta devices).deviceDependencies or { }) devices;
      in
      ''
        set -efux

        disko_devices_dir=$(mktemp -d)
        trap 'rm -rf "$disko_devices_dir"' EXIT
        mkdir -p "$disko_devices_dir"

        ${concatMapStrings (dev: (attrByPath (dev ++ [ "_create" ]) (_: {}) devices) {}) sortedDeviceList}
      '';
    /* Takes a disko device specification and returns a string which mounts the disks

       mount :: lib.types.devices -> str
    */
    mount = devices:
      let
        fsMounts = diskoLib.deepMergeMap (dev: (dev._mount { }).fs or { }) (flatten (map attrValues (attrValues devices)));
        sortedDeviceList = diskoLib.sortDevicesByDependencies ((diskoLib.meta devices).deviceDependencies or { }) devices;
      in
      ''
        set -efux
        # first create the necessary devices
        ${concatMapStrings (dev: ((attrByPath (dev ++ [ "_mount" ]) {} devices) {}).dev or "") sortedDeviceList}

        # and then mount the filesystems in alphabetical order
        ${concatStrings (attrValues fsMounts)}
      '';

    /* takes a disko device specification and returns a string which unmounts, destroys all disks and then runs create and mount

       zapCreateMount :: lib.types.devices -> str
    */
    zapCreateMount = devices: ''
      set -efux
      umount -Rv "${rootMountPoint}" || :

      for dev in ${toString (lib.catAttrs "device" (lib.attrValues devices.disk))}; do
        ${../disk-deactivate}/disk-deactivate "$dev" | bash -x
      done

      echo 'creating partitions...'
      ${diskoLib.create devices}
      echo 'mounting partitions...'
      ${diskoLib.mount devices}
    '';
    /* Takes a disko device specification and returns a nixos configuration

       config :: lib.types.devices -> nixosConfig
    */
    config = devices: flatten (map (dev: dev._config) (flatten (map attrValues (attrValues devices))));
    /* Takes a disko device specification and returns a function to get the needed packages to format/mount the disks

       packages :: lib.types.devices -> pkgs -> [ derivation ]
    */
    packages = devices: pkgs: unique (flatten (map (dev: dev._pkgs pkgs) (flatten (map attrValues (attrValues devices)))));
  };

  optionTypes = rec {
    filename = lib.mkOptionType {
      name = "filename";
      check = isString;
      merge = mergeOneOption;
      description = "A filename";
    };

    absolute-pathname = lib.mkOptionType {
      name = "absolute pathname";
      check = x: isString x && substring 0 1 x == "/" && pathname.check x;
      merge = mergeOneOption;
      description = "An absolute path";
    };

    pathname = lib.mkOptionType {
      name = "pathname";
      check = x:
        let
          # The filter is used to normalize paths, i.e. to remove duplicated and
          # trailing slashes.  It also removes leading slashes, thus we have to
          # check for "/" explicitly below.
          xs = filter (s: stringLength s > 0) (splitString "/" x);
        in
        isString x && (x == "/" || (length xs > 0 && all filename.check xs));
      merge = mergeOneOption;
      description = "A path name";
    };
  };

  /* topLevel type of the disko config, takes attrsets of disks, mdadms, zpools, nodevs, and lvm vgs.
  */
  devices = lib.types.submodule {
    options = {
      disk = lib.mkOption {
        type = lib.types.attrsOf subTypes.disk;
        default = { };
        description = "Block device";
      };
      mdadm = lib.mkOption {
        type = lib.types.attrsOf subTypes.mdadm;
        default = { };
        description = "mdadm device";
      };
      zpool = lib.mkOption {
        type = lib.types.attrsOf subTypes.zpool;
        default = { };
        description = "ZFS pool device";
      };
      lvm_vg = lib.mkOption {
        type = lib.types.attrsOf subTypes.lvm_vg;
        default = { };
        description = "LVM VG device";
      };
      nodev = lib.mkOption {
        type = lib.types.attrsOf subTypes.nodev;
        default = { };
        description = "A non-block device";
      };
    };
  };

  subTypes = lib.mapAttrs (_: diskoLib.mkSubType) {
    nodev =  ./nodev.nix;
    btrfs = ./btrfs.nix;
    btrfs_subvol = ./btrfs_subvol.nix;
    filesystem = ./filesystem.nix;
    table = ./table.nix;
    partition = ./partition.nix;
    swap = ./swap.nix;
    lvm_pv = ./lvm_pv.nix;
    lvm_vg = ./lvm_vg.nix;
    lvm_lv = ./lvm_lv.nix;
    zfs = ./zfs.nix;
    zpool = ./zpool.nix;
    zfs_dataset = ./zfs_dataset.nix;
    mdadm = ./mdadm.nix;
    mdraid = ./mdraid.nix;
    luks = ./luks.nix;
    disk =  ./disk.nix;
  };
}
