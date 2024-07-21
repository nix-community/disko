{ lib ? import <nixpkgs/lib>
, rootMountPoint ? "/mnt"
, makeTest ? import <nixpkgs/nixos/tests/make-test-python.nix>
, eval-config ? import <nixpkgs/nixos/lib/eval-config.nix>
}:
with lib;
with builtins;

let
  outputs = import ../default.nix { inherit lib diskoLib; };
  diskoLib = {

    # like make-disk-image.nix from nixpkgs, but with disko config
    makeDiskImages = args: (import ./make-disk-image.nix ({ inherit diskoLib; } // args)).pure;

    # a version of makeDiskImage which runs outside of the store
    makeDiskImagesScript = args: (import ./make-disk-image.nix ({ inherit diskoLib; } // args)).impure;

    makeVMRunner = args: (import ./interactive-vm.nix ({ inherit diskoLib; } // args)).pure;

    testLib = import ./tests.nix { inherit lib makeTest eval-config; };
    # like lib.types.oneOf but instead of a list takes an attrset
    # uses the field "type" to find the correct type in the attrset
    subType = { types, extraArgs ? { parent = { type = "rootNode"; name = "root"; }; } }: lib.mkOptionType {
      name = "subType";
      description = "one of ${concatStringsSep "," (attrNames types)}";
      check = x: if x ? type then types.${x.type}.check x else throw "No type option set in:\n${generators.toPretty {} x}";
      merge = loc: foldl'
        (_res: def: types.${def.value.type}.merge loc [
          # we add a dummy root parent node to render documentation
          (lib.recursiveUpdate { value._module.args = extraArgs; } def)
        ])
        { };
      nestedTypes = types;
    };

    # option for valid contents of partitions (basically like devices, but without tables)
    partitionType = extraArgs: lib.mkOption {
      type = lib.types.nullOr (diskoLib.subType {
        types = { inherit (diskoLib.types) btrfs filesystem zfs mdraid luks lvm_pv swap; };
        inherit extraArgs;
      });
      default = null;
      description = "The type of partition";
    };

    # option for valid contents of devices
    deviceType = extraArgs: lib.mkOption {
      type = lib.types.nullOr (diskoLib.subType {
        types = { inherit (diskoLib.types) table gpt btrfs filesystem zfs mdraid luks lvm_pv swap; };
        inherit extraArgs;
      });
      default = null;
      description = "The type of device";
    };

    /* deepMergeMap takes a function and a list of attrsets and deep merges them

       deepMergeMap :: (AttrSet -> AttrSet ) -> [ AttrSet ] -> Attrset

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
      if match "/dev/([vs]|(xv)d).+" dev != null then
        dev + toString index  # /dev/{s,v,xv}da style
      else if match "/dev/(disk|zvol)/.+" dev != null then
        "${dev}-part${toString index}" # /dev/disk/by-id/xxx style, also used by zfs's zvolumes
      else if match "/dev/((nvme|mmcblk).+|md/.*[[:digit:]])" dev != null then
        "${dev}p${toString index}" # /dev/nvme0n1p1 style
      else if match "/dev/md/.+" dev != null then
        "${dev}${toString index}" # /dev/md/raid1 style
      else if match "/dev/mapper/.+" dev != null then
        "${dev}${toString index}" # /dev/mapper/vg-lv1 style
      else if match "/dev/loop[[:digit:]]+" dev != null
      then "${dev}p${toString index}" # /dev/mapper/vg-lv1 style
      else
        abort ''
          ${dev} seems not to be a supported disk format. Please add this to disko in https://github.com/nix-community/disko/blob/master/lib/default.nix
        '';

    /* get the index an item in a list

       indexOf :: (a -> bool) -> [a] -> int -> int

       Example:
       indexOf (x: x == 2) [ 1 2 3 ] 0
       => 2

       indexOf (x: x == "x") [ 1 2 3 ] 0
       => 0
    */
    indexOf = f: list: fallback:
      let
        iter = index: list:
          if list == [ ] then
            fallback
          else if f (head list) then
            index
          else
            iter (index + 1) (tail list);
      in
      iter 1 list;


    /* indent takes a multiline string and indents it by 2 spaces starting on the second line

       indent :: str -> str

       Example:
       indent "test\nbla"
       => "test\n  bla"
    */
    indent = replaceStrings [ "\n" ] [ "\n  " ];

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
    defineHookVariables = { options }:
      let
        sanitizeName = lib.replaceStrings [ "-" ] [ "_" ];
        isAttrsOfSubmodule = o: o.type.name == "attrsOf" && o.type.nestedTypes.elemType.name == "submodule";
        isSerializable = n: o: !(
          lib.hasPrefix "_" n
            || lib.hasSuffix "Hook" n
            || isAttrsOfSubmodule o
            # TODO don't hardcode diskoLib.subType options.
            || n == "content" || n == "partitions" || n == "datasets" || n == "swap"
        );
      in
      lib.toShellVars
        (lib.mapAttrs'
          (n: o: lib.nameValuePair (sanitizeName n) o.value)
          (lib.filterAttrs isSerializable options));

    mkHook = description: lib.mkOption {
      inherit description;
      type = lib.types.lines;
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
          inherit diskoLib rootMountPoint;
        };
      }
    ];

    mkCreateOption = { config, options, default }@attrs:
      lib.mkOption {
        internal = true;
        readOnly = true;
        type = lib.types.str;
        default = ''
          ( # ${config.type} ${concatMapStringsSep " " (n: toString (config.${n} or "")) ["name" "device" "format" "mountpoint"]} #
            ${diskoLib.indent (diskoLib.defineHookVariables { inherit options; })}
            ${diskoLib.indent config.preCreateHook}
            ${diskoLib.indent attrs.default}
            ${diskoLib.indent config.postCreateHook}
          )
        '';
        description = "Creation script";
      };

    mkMountOption = { config, options, default }@attrs:
      lib.mkOption {
        internal = true;
        readOnly = true;
        type = diskoLib.jsonType;
        default = lib.mapAttrsRecursive
          (_name: value:
            if builtins.isString value then ''
              (
                ${diskoLib.indent (diskoLib.defineHookVariables { inherit options; })}
                ${diskoLib.indent config.preMountHook}
                ${diskoLib.indent value}
                ${diskoLib.indent config.postMountHook}
              )
            '' else value)
          attrs.default;
        description = "Mount script";
      };

    /* Writer for optionally checking bash scripts before writing them to the store

       writeCheckedBash :: AttrSet -> str -> str -> derivation
    */
    writeCheckedBash = { pkgs, checked ? false, noDeps ? false }: pkgs.writers.makeScriptWriter {
      interpreter = if noDeps then "/usr/bin/env bash" else "${pkgs.bash}/bin/bash";
      check = lib.optionalString (checked && !pkgs.hostPlatform.isRiscV64 && !pkgs.hostPlatform.isx86_32) (pkgs.writeScript "check" ''
        set -efu
        ${pkgs.shellcheck}/bin/shellcheck -e SC2034 "$1"
      '');
    };


    /* Takes a disko device specification, returns an attrset with metadata

       meta :: lib.types.devices -> AttrSet
    */
    meta = toplevel: toplevel._meta;

    /* Takes a disko device specification and returns a string which formats the disks

       create :: lib.types.devices -> str
    */
    create = toplevel: toplevel._create;
    /* Takes a disko device specification and returns a string which mounts the disks

       mount :: lib.types.devices -> str
    */
    mount = toplevel: toplevel._mount;

    /* takes a disko device specification and returns a string which unmounts, destroys all disks and then runs create and mount

       zapCreateMount :: lib.types.devices -> str
    */
    zapCreateMount = toplevel:
      ''
        set -efux
        ${toplevel._disko}
      '';
    /* Takes a disko device specification and returns a nixos configuration

       config :: lib.types.devices -> nixosConfig
    */
    config = toplevel: toplevel._config;

    /* Takes a disko device specification and returns a function to get the needed packages to format/mount the disks

       packages :: lib.types.devices -> pkgs -> [ derivation ]
    */
    packages = toplevel: toplevel._packages;

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
    toplevel = lib.types.submodule (cfg:
      let
        devices = { inherit (cfg.config) disk mdadm zpool lvm_vg nodev; };
      in
      {
        options = {
          disk = lib.mkOption {
            type = lib.types.attrsOf diskoLib.types.disk;
            default = { };
            description = "Block device";
          };
          mdadm = lib.mkOption {
            type = lib.types.attrsOf diskoLib.types.mdadm;
            default = { };
            description = "mdadm device";
          };
          zpool = lib.mkOption {
            type = lib.types.attrsOf diskoLib.types.zpool;
            default = { };
            description = "ZFS pool device";
          };
          lvm_vg = lib.mkOption {
            type = lib.types.attrsOf diskoLib.types.lvm_vg;
            default = { };
            description = "LVM VG device";
          };
          nodev = lib.mkOption {
            type = lib.types.attrsOf diskoLib.types.nodev;
            default = { };
            description = "A non-block device";
          };
          _meta = lib.mkOption {
            internal = true;
            description = ''
              meta informationen generated by disko
              currently used for building a dependency list so we know in which order to create the devices
            '';
            default = diskoLib.deepMergeMap (dev: dev._meta) (flatten (map attrValues (attrValues devices)));
          };
          _packages = lib.mkOption {
            internal = true;
            description = ''
              packages required by the disko configuration
              coreutils is always included
            '';
            default = pkgs: unique ((flatten (map (dev: dev._pkgs pkgs) (flatten (map attrValues (attrValues devices))))) ++ [ pkgs.coreutils-full ]);
          };
          _scripts = lib.mkOption {
            internal = true;
            description = ''
              The scripts generated by disko
            '';
            default = { pkgs, checked ? false }: {
              destroyScript = (diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko-destroy" ''
                export PATH=${lib.makeBinPath (with pkgs; [
                  util-linux
                  e2fsprogs
                  mdadm
                  zfs
                  lvm2
                  bash
                  jq
                  gnused
                  gawk
                  coreutils-full
                ])}:$PATH
                ${cfg.config._destroy}
              '';

              formatScript = (diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko-format" ''
                export PATH=${lib.makeBinPath (cfg.config._packages pkgs)}:$PATH
                ${cfg.config._create}
              '';

              mountScript = (diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko-mount" ''
                export PATH=${lib.makeBinPath (cfg.config._packages pkgs)}:$PATH
                ${cfg.config._mount}
              '';

              diskoScript = (diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko" ''
                export PATH=${lib.makeBinPath ((cfg.config._packages pkgs) ++ [ pkgs.bash ])}:$PATH
                ${cfg.config._disko}
              '';

              # These are useful to skip copying executables uploading a script to an in-memory installer
              destroyScriptNoDeps = (diskoLib.writeCheckedBash { inherit pkgs checked; noDeps = true; }) "disko-destroy" ''
                ${cfg.config._destroy}
              '';

              formatScriptNoDeps = (diskoLib.writeCheckedBash { inherit pkgs checked; noDeps = true; }) "disko-format" ''
                ${cfg.config._create}
              '';

              mountScriptNoDeps = (diskoLib.writeCheckedBash { inherit pkgs checked; noDeps = true; }) "disko-mount" ''
                ${cfg.config._mount}
              '';

              diskoScriptNoDeps = (diskoLib.writeCheckedBash { inherit pkgs checked; noDeps = true; }) "disko" ''
                ${cfg.config._disko}
              '';
            };
          };
          _destroy = lib.mkOption {
            internal = true;
            type = lib.types.str;
            description = ''
              The script to unmount (& destroy) all devices defined by disko.devices
            '';
            default = ''
              umount -Rv "${rootMountPoint}" || :

              # shellcheck disable=SC2043
              for dev in ${toString (lib.catAttrs "device" (lib.attrValues devices.disk))}; do
                $BASH ${../disk-deactivate}/disk-deactivate "$dev"
              done
            '';
          };
          _create = lib.mkOption {
            internal = true;
            type = lib.types.str;
            description = ''
              The script to create all devices defined by disko.devices
            '';
            default =
              let
                sortedDeviceList = diskoLib.sortDevicesByDependencies (cfg.config._meta.deviceDependencies or { }) devices;
              in
              ''
                set -efux

                disko_devices_dir=$(mktemp -d)
                trap 'rm -rf "$disko_devices_dir"' EXIT
                mkdir -p "$disko_devices_dir"

                ${concatMapStrings (dev: (attrByPath (dev ++ [ "_create" ]) {} devices)) sortedDeviceList}
              '';
          };
          _mount = lib.mkOption {
            internal = true;
            type = lib.types.str;
            description = ''
              The script to mount all devices defined by disko.devices
            '';
            default =
              let
                fsMounts = diskoLib.deepMergeMap (dev: dev._mount.fs or { }) (flatten (map attrValues (attrValues devices)));
                sortedDeviceList = diskoLib.sortDevicesByDependencies (cfg.config._meta.deviceDependencies or { }) devices;
              in
              ''
                set -efux
                # first create the necessary devices
                ${concatMapStrings (dev: (attrByPath (dev ++ [ "_mount" ]) {} devices).dev or "") sortedDeviceList}

                # and then mount the filesystems in alphabetical order
                ${concatStrings (attrValues fsMounts)}
              '';
          };
          _disko = lib.mkOption {
            internal = true;
            type = lib.types.str;
            description = ''
              The script to umount, create and mount all devices defined by disko.devices
            '';
            default = ''
              ${cfg.config._destroy}
              ${cfg.config._create}
              ${cfg.config._mount}
            '';
          };
          _config = lib.mkOption {
            internal = true;
            description = ''
              The NixOS config generated by disko
            '';
            default =
              let
                configKeys = flatten (map attrNames (flatten (map (dev: dev._config) (flatten (map attrValues (attrValues devices))))));
                collectedConfigs = flatten (map (dev: dev._config) (flatten (map attrValues (attrValues devices))));
              in
              lib.genAttrs configKeys (key: lib.mkMerge (lib.catAttrs key collectedConfigs));
          };
        };
      });

    # import all the types from the types directory
    types = lib.listToAttrs (
      map
        (file: lib.nameValuePair
          (lib.removeSuffix ".nix" file)
          (diskoLib.mkSubType ./types/${file})
        )
        (lib.attrNames (builtins.readDir ./types))
    );


    # render types into an json serializable format
    serializeType = type:
      let
        options = lib.filter (x: !lib.hasPrefix "_" x) (lib.attrNames type.options);
      in
      lib.listToAttrs (
        map
          (option: lib.nameValuePair
            option
            type.options.${option}
          )
          options
      );

    typesSerializerLib = {
      rootMountPoint = "";
      options = null;
      config._module.args.name = "self.name";
      lib = {
        mkOption = option: {
          inherit (option) type description;
          default = option.default or null;
        };
        types = {
          attrsOf = subType: {
            type = "attrsOf";
            inherit subType;
          };
          listOf = subType: {
            type = "listOf";
            inherit subType;
          };
          nullOr = subType: {
            type = "nullOr";
            inherit subType;
          };
          enum = choices: {
            type = "enum";
            inherit choices;
          };
          str = "str";
          bool = "bool";
          int = "int";
          submodule = x: x { inherit (diskoLib.typesSerializerLib) lib config options; };
        };
      };
      diskoLib = {
        optionTypes.absolute-pathname = "absolute-pathname";
        deviceType = "devicetype";
        partitionType = "partitiontype";
        subType = types: "onOf ${toString (lib.attrNames types)}";
      };
    };

    jsonTypes = lib.listToAttrs (
      map
        (file: lib.nameValuePair
          (lib.removeSuffix ".nix" file)
          (diskoLib.serializeType (import ./types/${file} diskoLib.typesSerializerLib))
        )
        (lib.attrNames (builtins.readDir ./types))
    );

  } // outputs;
in
diskoLib
