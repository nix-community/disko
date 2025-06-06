{
  lib ? import <nixpkgs/lib>,
  rootMountPoint ? "/mnt",
  makeTest ? import <nixpkgs/nixos/tests/make-test-python.nix>,
  eval-config ? import <nixpkgs/nixos/lib/eval-config.nix>,
}:
let
  outputs = import ../default.nix { inherit lib diskoLib; };
  diskoLib = {
    testLib = import ./tests.nix { inherit lib makeTest eval-config; };
    # like lib.types.oneOf but instead of a list takes an attrset
    # uses the field "type" to find the correct type in the attrset
    subType =
      {
        types,
        extraArgs ? {
          parent = {
            type = "rootNode";
            name = "root";
          };
        },
      }:
      lib.mkOptionType {
        name = "subType";
        description = "one of ${lib.concatStringsSep "," (lib.attrNames types)}";
        check =
          x:
          if x ? type then
            types.${x.type}.check x
          else
            throw "No type option set in:\n${lib.generators.toPretty { } x}";
        merge =
          loc:
          lib.foldl' (
            _res: def:
            types.${def.value.type}.merge loc [
              # we add a dummy root parent node to render documentation
              (lib.recursiveUpdate { value._module.args = extraArgs; } def)
            ]
          ) { };
        nestedTypes = types;
      };

    # option for valid contents of partitions (basically like devices, but without tables)
    _partitionTypes = {
      inherit (diskoLib.types)
        bcachefs
        btrfs
        filesystem
        zfs
        mdraid
        luks
        lvm_pv
        swap
        ;
    };
    partitionType =
      extraArgs:
      lib.mkOption {
        type = lib.types.nullOr (
          diskoLib.subType {
            types = diskoLib._partitionTypes;
            inherit extraArgs;
          }
        );
        default = null;
        description = "The type of partition";
      };

    # option for valid contents of devices
    _deviceTypes = {
      inherit (diskoLib.types)
        bcachefs
        table
        gpt
        btrfs
        filesystem
        zfs
        mdraid
        luks
        lvm_pv
        swap
        ;
    };
    deviceType =
      extraArgs:
      lib.mkOption {
        type = lib.types.nullOr (
          diskoLib.subType {
            types = diskoLib._deviceTypes;
            inherit extraArgs;
          }
        );
        default = null;
        description = "The type of device";
      };

    /**
        like lib.recursiveUpdate but supports merging of lists

        # Inputs:

         `left`

         : Left  attribute set of the merge

         `right`

        : Right attribute set of the merge

        recursiveUpdate :: AttrSet -> AttrSet -> AttrSet

        # Examples
        :::{.example}
        ```nix
        recursiveUpdate {
          boot.loader.grub.enable = true;
          boot.loader.grub.devices = [ "/dev/hda" ];
        } {
          boot.loader.grub.devices = [ "/dev/hdb" ];
        }

        returns: {
          boot.loader.grub.enable = true;
          boot.loader.grub.devices = [ "/dev/hda" "/dev/hdb" ];
        }
        ```
      *
    */
    recursiveUpdate =
      left: right:
      let
        inherit (lib)
          zipAttrsWith
          length
          elemAt
          head
          isAttrs
          isList
          concatLists
          all
          reverseList
          ;

        recursiveMergeUntil =
          pred: lhs: rhs:
          let
            f =
              attrPath:
              zipAttrsWith (
                n: values:
                let
                  here = attrPath ++ [ n ];
                in
                if length values == 1 || pred here (elemAt values 1) (head values) then
                  (if all isList values then concatLists (reverseList values) else head values)
                else
                  f here values
              );
          in
          f [ ] [ rhs lhs ];

        recursiveMerge =
          lhs: rhs:
          recursiveMergeUntil (
            _path: lhs: rhs:
            !(isAttrs lhs && isAttrs rhs)
          ) lhs rhs;
      in
      recursiveMerge left right;

    /*
      deepMergeMap takes a function and a list of attrsets and deep merges them

      deepMergeMap :: (AttrSet -> AttrSet ) -> [ AttrSet ] -> Attrset

      Example:
        deepMergeMap (x: x.t = "test") [ { x = { y = 1; z = 3; }; } { x = { bla = 234; }; } ]
        => { x = { y = 1; z = 3; bla = 234; t = "test"; }; }
    */
    deepMergeMap = f: lib.foldr (attr: acc: (diskoLib.recursiveUpdate acc (f attr))) { };

    /*
      get a device and an index to get the matching device name

      deviceNumbering :: str -> int -> str

      Example:
      deviceNumbering "/dev/sda" 3
      => "/dev/sda3"

      deviceNumbering "/dev/disk/by-id/xxx" 2
      => "/dev/disk/by-id/xxx-part2"
    */
    deviceNumbering =
      dev: index:
      let
        inherit (lib) match;
      in
      if match "/dev/([vs]|(xv)d).+" dev != null then
        dev + toString index # /dev/{s,v,xv}da style
      else if match "/dev/(disk|zvol)/.+" dev != null then
        "${dev}-part${toString index}" # /dev/disk/by-id/xxx style, also used by zfs's zvolumes
      else if match "/dev/((nvme|mmcblk).+|md/.*[[:digit:]])" dev != null then
        "${dev}p${toString index}" # /dev/nvme0n1p1 style
      else if match "/dev/md/.+" dev != null then
        "${dev}${toString index}" # /dev/md/raid1 style
      else if match "/dev/mapper/.+" dev != null then
        "${dev}${toString index}" # /dev/mapper/vg-lv1 style
      else if match "/dev/loop[[:digit:]]+" dev != null then
        "${dev}p${toString index}" # /dev/mapper/vg-lv1 style
      else
        abort ''
          ${dev} seems not to be a supported disk format. Please add this to disko in https://github.com/nix-community/disko/blob/master/lib/default.nix
        '';

    /*
      Escape a string as required to be used in udev symlinks

      The allowed characters are "0-9A-Za-z#+-.:=@_/", valid UTF-8 character sequences, and "\x00" hex encoding.
      Everything else is escaped as "\xXX" where XX is the hex value of the character.

      The source of truth for the list of allowed characters is the udev documentation:
      https://www.freedesktop.org/software/systemd/man/latest/udev.html#SYMLINK1

      This function is implemented as a best effort. It is not guaranteed to be 100% in line
      with the udev implementation, and we hope that you're not crazy enough to try to break it.

      hexEscapeUdevSymlink :: str -> str

      Example:
      hexEscapeUdevSymlink "Boot data partition"
      => "Boot\x20data\x20partition"

      hexEscapeUdevSymlink "Even(crazier)par&titi^onName"
      => "Even\x28crazier\x29par\x26titi\x5EonName"

      hexEscapeUdevSymlink "all0these@char#acters+_are-allow.ed"
      => "all0these@char#acters+_are-allow.ed"
    */
    hexEscapeUdevSymlink =
      let
        allowedChars = "[0-9A-Za-z#+-.:=@_/]";
        charToHex = c: lib.toHexString (lib.strings.charToInt c);
      in
      lib.stringAsChars (
        c: if lib.match allowedChars c != null || c == "" then c else "\\x" + charToHex c
      );

    /*
      get the index an item in a list

      indexOf :: (a -> bool) -> [a] -> int -> int

      Example:
      indexOf (x: x == 2) [ 1 2 3 ] 0
      => 2

      indexOf (x: x == "x") [ 1 2 3 ] 0
      => 0
    */
    indexOf =
      f: list: fallback:
      let
        iter =
          index: list:
          if list == [ ] then
            fallback
          else if f (lib.head list) then
            index
          else
            iter (index + 1) (lib.tail list);
      in
      iter 1 list;

    /*
      indent takes a multiline string and indents it by 2 spaces starting on the second line

      indent :: str -> str

      Example:
      indent "test\nbla"
      => "test\n  bla"
    */
    indent = lib.replaceStrings [ "\n" ] [ "\n  " ];

    # A nix option type representing a json datastructure, vendored from nixpkgs to avoid dependency on pkgs
    jsonType =
      let
        valueType =
          lib.types.nullOr (
            lib.types.oneOf [
              lib.types.bool
              lib.types.int
              lib.types.float
              lib.types.str
              lib.types.path
              (lib.types.attrsOf valueType)
              (lib.types.listOf valueType)
            ]
          )
          // {
            description = "JSON value";
          };
      in
      valueType;

    /*
      Given a attrset of deviceDependencies and a devices attrset
      returns a sorted list by deviceDependencies. aborts if a loop is found

      sortDevicesByDependencies :: AttrSet -> AttrSet -> [ [ str str ] ]
    */
    sortDevicesByDependencies =
      deviceDependencies: devices:
      let
        dependsOn = a: b: lib.elem a (lib.attrByPath b [ ] deviceDependencies);
        maybeSortedDevices = lib.toposort dependsOn (diskoLib.deviceList devices);
      in
      if (lib.hasAttr "cycle" maybeSortedDevices) then
        abort "detected a cycle in your disk setup: ${maybeSortedDevices.cycle}"
      else
        maybeSortedDevices.result;

    /*
      Takes a devices attrSet and returns it as a list

      deviceList :: AttrSet -> [ [ str str ] ]

      Example:
        deviceList { zfs.pool1 = {}; zfs.pool2 = {}; mdadm.raid1 = {}; }
        => [ [ "zfs" "pool1" ] [ "zfs" "pool2" ] [ "mdadm" "raid1" ] ]
    */
    deviceList =
      devices:
      lib.concatLists (
        lib.mapAttrsToList (
          n: v:
          (map (x: [
            n
            x
          ]) (lib.attrNames v))
        ) devices
      );

    /*
      Takes either a string or null and returns the string or an empty string

      maybeStr :: Either (str null) -> str

      Example:
        maybeStr null
        => ""
        maybeSTr "hello world"
        => "hello world"
    */
    maybeStr = x: lib.optionalString (x != null) x;

    /*
      Check whenever `b` depends on `a` as a fileSystem

      Note: copied from nixpkgs/nixos/utils.nix @ 47718fe8858fa4642cd6a4f0b5a1173bad9ce8df
      because the file that exports it is not meant to be used standalone.
    */
    fsBefore =
      a: b:
      with lib;
      let
        # normalisePath adds a slash at the end of the path if it didn't already
        # have one.
        #
        # The reason slashes are added at the end of each path is to prevent `b`
        # from accidentally depending on `a` in cases like
        #    a = { mountPoint = "/aaa"; ... }
        #    b = { device     = "/aaaa"; ... }
        # Here a.mountPoint *is* a prefix of b.device even though a.mountPoint is
        # *not* a parent of b.device. If we add a slash at the end of each string,
        # though, this is not a problem: "/aaa/" is not a prefix of "/aaaa/".
        normalisePath = path: "${path}${optionalString (!(hasSuffix "/" path)) "/"}";
        normalise =
          mount:
          mount
          // {
            device = normalisePath (toString mount.device);
            mountPoint = normalisePath mount.mountPoint;
            depends = map normalisePath mount.depends;
          };

        a' = normalise a;
        b' = normalise b;

      in
      hasPrefix a'.mountPoint b'.device
      || hasPrefix a'.mountPoint b'.mountPoint
      || any (hasPrefix a'.mountPoint) b'.depends;

    /*
      Takes a Submodules config and options argument and returns a serializable
      subset of config variables as a shell script snippet.
    */
    defineHookVariables =
      { options }:
      let
        sanitizeName = lib.replaceStrings [ "-" ] [ "_" ];
        isAttrsOfSubmodule = o: o.type.name == "attrsOf" && o.type.nestedTypes.elemType.name == "submodule";
        isSerializable =
          n: o:
          !(
            lib.hasPrefix "_" n
            || lib.hasSuffix "Hook" n
            || isAttrsOfSubmodule o
            # TODO don't hardcode diskoLib.subType options.
            || n == "content"
            || n == "partitions"
            || n == "datasets"
            || n == "swap"
            || n == "mode"
          );
      in
      lib.toShellVars (
        lib.mapAttrs' (n: o: lib.nameValuePair (sanitizeName n) o.value) (
          lib.filterAttrs isSerializable options
        )
      );

    mkHook =
      description:
      lib.mkOption {
        inherit description;
        type = lib.types.lines;
        default = "";
      };

    mkSubType =
      module:
      lib.types.submodule [
        module

        {
          options = {
            preCreateHook = diskoLib.mkHook "shell commands to run before create";
            postCreateHook = diskoLib.mkHook "shell commands to run after create";
            preMountHook = diskoLib.mkHook "shell commands to run before mount";
            postMountHook = diskoLib.mkHook "shell commands to run after mount";
            preUnmountHook = diskoLib.mkHook "shell commands to run before unmount";
            postUnmountHook = diskoLib.mkHook "shell commands to run after unmount";
          };
          config._module.args = {
            inherit diskoLib rootMountPoint;
          };
        }
      ];

    mkCreateOption =
      {
        config,
        options,
        default,
      }@attrs:
      lib.mkOption {
        internal = true;
        readOnly = true;
        type = lib.types.str;
        default = ''
          ( # ${config.type} ${
            lib.concatMapStringsSep " " (n: toString (config.${n} or "")) [
              "name"
              "device"
              "format"
              "mountpoint"
            ]
          } #
            ${diskoLib.indent (diskoLib.defineHookVariables { inherit options; })}
            ${diskoLib.indent config.preCreateHook}
            ${diskoLib.indent attrs.default}
            ${diskoLib.indent config.postCreateHook}
          )
        '';
        description = "Creation script";
      };

    mkMountOption =
      {
        config,
        options,
        default,
      }@attrs:
      lib.mkOption {
        internal = true;
        readOnly = true;
        type = diskoLib.jsonType;
        default = lib.mapAttrsRecursive (
          _name: value:
          if builtins.isString value then
            ''
              (
                ${diskoLib.indent (diskoLib.defineHookVariables { inherit options; })}
                ${diskoLib.indent config.preMountHook}
                ${diskoLib.indent value}
                ${diskoLib.indent config.postMountHook}
              )
            ''
          else
            value
        ) attrs.default;
        description = "Mount script";
      };

    mkUnmountOption =
      {
        config,
        options,
        default,
      }@attrs:
      lib.mkOption {
        internal = true;
        readOnly = true;
        type = diskoLib.jsonType;
        default = lib.mapAttrsRecursive (
          _name: value:
          if builtins.isString value then
            ''
              (
                ${diskoLib.indent (diskoLib.defineHookVariables { inherit options; })}
                ${diskoLib.indent config.preUnmountHook}
                ${diskoLib.indent value}
                ${diskoLib.indent config.postUnmountHook}
              )
            ''
          else
            value
        ) attrs.default;
        description = "Unmount script";
      };

    /*
      Writer for optionally checking bash scripts before writing them to the store

      writeCheckedBash :: AttrSet -> str -> str -> derivation
    */
    writeCheckedBash =
      {
        pkgs,
        checked ? false,
        noDeps ? false,
      }:
      pkgs.writers.makeScriptWriter {
        interpreter = if noDeps then "/usr/bin/env bash" else "${pkgs.bash}/bin/bash";
        check =
          lib.optionalString
            (checked && !pkgs.stdenv.hostPlatform.isRiscV64 && !pkgs.stdenv.hostPlatform.isx86_32)
            (
              pkgs.writeScript "check" ''
                set -efu
                # SC2054: our toShellVars function doesn't quote list elements with commas
                # SC2034: We don't use all variables exported by hooks.
                ${pkgs.shellcheck}/bin/shellcheck -e SC2034,SC2054 "$1"
              ''
            );
      };

    /*
      Takes a disko device specification, returns an attrset with metadata

      meta :: lib.types.devices -> AttrSet
    */
    meta = toplevel: toplevel._meta;

    /*
      Takes a disko device specification and returns a string which formats the disks

      create :: lib.types.devices -> str
    */
    create = toplevel: toplevel._create;
    /*
      Takes a disko device specification and returns a string which mounts the disks

      mount :: lib.types.devices -> str
    */
    mount = toplevel: toplevel._mount;

    /*
      takes a disko device specification and returns a string which unmounts, destroys all disks and then runs create and mount

      zapCreateMount :: lib.types.devices -> str
    */
    zapCreateMount = toplevel: ''
      set -efux
      ${toplevel._disko}
    '';
    /*
      Takes a disko device specification and returns a nixos configuration

      config :: lib.types.devices -> nixosConfig
    */
    config = toplevel: toplevel._config;

    /*
      Takes a disko device specification and returns a function to get the needed packages to format/mount the disks

      packages :: lib.types.devices -> pkgs -> [ derivation ]
    */
    packages = toplevel: toplevel._packages;

    /*
      Checks whether nixpkgs is recent enough for vmTools to support the customQemu argument.

      Returns false, which is technically incorrect, for a few commits on 2024-07-08, but we can't be more accurate.
      Make sure to pass lib, not pkgs.lib! See https://github.com/nix-community/disko/issues/904

      vmToolsSupportsCustomQemu :: final_lib -> bool
    */
    vmToolsSupportsCustomQemu = final_lib: lib.versionAtLeast final_lib.version "24.11.20240709";

    optionTypes = rec {
      filename = lib.mkOptionType {
        name = "filename";
        check = lib.isString;
        merge = lib.mergeOneOption;
        description = "A filename";
      };

      absolute-pathname = lib.mkOptionType {
        name = "absolute pathname";
        check = x: lib.isString x && lib.substring 0 1 x == "/" && pathname.check x;
        merge = lib.mergeOneOption;
        description = "An absolute path";
      };

      pathname = lib.mkOptionType {
        name = "pathname";
        check =
          x:
          with lib;
          let
            # The filter is used to normalize paths, i.e. to remove duplicated and
            # trailing slashes.  It also removes leading slashes, thus we have to
            # check for "/" explicitly below.
            xs = filter (s: stringLength s > 0) (splitString "/" x);
          in
          isString x && (x == "/" || (length xs > 0 && all filename.check xs));
        merge = lib.mergeOneOption;
        description = "A path name";
      };
    };

    # topLevel type of the disko config, takes attrsets of disks, mdadms, zpools, nodevs, and lvm vgs.
    toplevel = lib.types.submodule (
      cfg:
      let
        devices = {
          inherit (cfg.config)
            bcachefs_filesystems
            disk
            mdadm
            zpool
            lvm_vg
            nodev
            ;
        };
      in
      {
        options = {
          bcachefs_filesystems = lib.mkOption {
            type = lib.types.attrsOf diskoLib.types.bcachefs_filesystem;
            default = { };
            description = "bcachefs filesystem";
          };
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
            default = diskoLib.deepMergeMap (dev: dev._meta) (
              lib.flatten (map lib.attrValues (lib.attrValues devices))
            );
          };
          _packages = lib.mkOption {
            internal = true;
            description = ''
              packages required by the disko configuration
              coreutils is always included
            '';
            default =
              pkgs:
              with lib;
              unique (
                (flatten (map (dev: dev._pkgs pkgs) (flatten (map attrValues (attrValues devices)))))
                ++ [ pkgs.coreutils-full ]
              );
          };
          _scripts = lib.mkOption {
            internal = true;
            description = ''
              The scripts generated by disko
            '';
            default =
              {
                pkgs,
                checked ? false,
              }:
              let
                throwIfNoDisksDetected =
                  _: v:
                  if devices.disk == { } then
                    throw "No disks defined, did you forget to import your disko config?"
                  else
                    v;
                # @todo Do we need to add bcachefs-tools or not?
                destroyDependencies = with pkgs; [
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
                ];
              in
              lib.mapAttrs throwIfNoDisksDetected {
                destroy = (diskoLib.writeCheckedBash { inherit pkgs checked; }) "/bin/disko-destroy" ''
                  export PATH=${lib.makeBinPath destroyDependencies}:$PATH
                  ${cfg.config._destroy}
                '';
                format = (diskoLib.writeCheckedBash { inherit pkgs checked; }) "/bin/disko-format" ''
                  export PATH=${lib.makeBinPath (cfg.config._packages pkgs)}:$PATH
                  ${cfg.config._create}
                '';
                mount = (diskoLib.writeCheckedBash { inherit pkgs checked; }) "/bin/disko-mount" ''
                  export PATH=${lib.makeBinPath (cfg.config._packages pkgs)}:$PATH
                  ${cfg.config._mount}
                '';
                unmount = (diskoLib.writeCheckedBash { inherit pkgs checked; }) "/bin/disko-unmount" ''
                  export PATH=${lib.makeBinPath (cfg.config._packages pkgs)}:$PATH
                  ${cfg.config._unmount}
                '';
                formatMount = (diskoLib.writeCheckedBash { inherit pkgs checked; }) "/bin/disko-format-mount" ''
                  export PATH=${lib.makeBinPath ((cfg.config._packages pkgs) ++ [ pkgs.bash ])}:$PATH
                  ${cfg.config._formatMount}
                '';
                destroyFormatMount =
                  (diskoLib.writeCheckedBash { inherit pkgs checked; }) "/bin/disko-destroy-format-mount"
                    ''
                      export PATH=${
                        lib.makeBinPath ((cfg.config._packages pkgs) ++ [ pkgs.bash ] ++ destroyDependencies)
                      }:$PATH
                      ${cfg.config._destroyFormatMount}
                    '';

                # These are useful to skip copying executables uploading a script to an in-memory installer
                destroyNoDeps =
                  (diskoLib.writeCheckedBash {
                    inherit pkgs checked;
                    noDeps = true;
                  })
                    "/bin/disko-destroy"
                    ''
                      ${cfg.config._destroy}
                    '';
                formatNoDeps =
                  (diskoLib.writeCheckedBash {
                    inherit pkgs checked;
                    noDeps = true;
                  })
                    "/bin/disko-format"
                    ''
                      ${cfg.config._create}
                    '';
                mountNoDeps =
                  (diskoLib.writeCheckedBash {
                    inherit pkgs checked;
                    noDeps = true;
                  })
                    "/bin/disko-mount"
                    ''
                      ${cfg.config._mount}
                    '';
                unmountNoDeps =
                  (diskoLib.writeCheckedBash {
                    inherit pkgs checked;
                    noDeps = true;
                  })
                    "/bin/disko-unmount"
                    ''
                      ${cfg.config._unmount}
                    '';
                formatMountNoDeps =
                  (diskoLib.writeCheckedBash {
                    inherit pkgs checked;
                    noDeps = true;
                  })
                    "/bin/disko-format-mount"
                    ''
                      ${cfg.config._formatMount}
                    '';
                destroyFormatMountNoDeps =
                  (diskoLib.writeCheckedBash {
                    inherit pkgs checked;
                    noDeps = true;
                  })
                    "/bin/disko-destroy-format-mount"
                    ''
                      ${cfg.config._destroyFormatMount}
                    '';

                # Legacy scripts, to be removed in version 2.0.0
                # They are generally less useful, because the scripts are directly written to their $out path instead of
                # into the $out/bin directory, which makes them incompatible with `nix run`
                # (see https://github.com/nix-community/disko/pull/78), `lib.buildEnv` and thus `environment.systemPackages`,
                # `user.users.<name>.packages` and `home.packages`, see https://github.com/nix-community/disko/issues/454
                destroyScript = (diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko-destroy" ''
                  export PATH=${lib.makeBinPath destroyDependencies}:$PATH
                  ${cfg.config._legacyDestroy}
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
                  export PATH=${
                    lib.makeBinPath ((cfg.config._packages pkgs) ++ [ pkgs.bash ] ++ destroyDependencies)
                  }:$PATH
                  ${cfg.config._disko}
                '';

                # These are useful to skip copying executables uploading a script to an in-memory installer
                destroyScriptNoDeps =
                  (diskoLib.writeCheckedBash {
                    inherit pkgs checked;
                    noDeps = true;
                  })
                    "disko-destroy"
                    ''
                      ${cfg.config._legacyDestroy}
                    '';

                formatScriptNoDeps =
                  (diskoLib.writeCheckedBash {
                    inherit pkgs checked;
                    noDeps = true;
                  })
                    "disko-format"
                    ''
                      ${cfg.config._create}
                    '';

                mountScriptNoDeps =
                  (diskoLib.writeCheckedBash {
                    inherit pkgs checked;
                    noDeps = true;
                  })
                    "disko-mount"
                    ''
                      ${cfg.config._mount}
                    '';

                diskoScriptNoDeps =
                  (diskoLib.writeCheckedBash {
                    inherit pkgs checked;
                    noDeps = true;
                  })
                    "disko"
                    ''
                      ${cfg.config._disko}
                    '';
              };
          };
          _legacyDestroy = lib.mkOption {
            internal = true;
            type = lib.types.str;
            description = ''
              The script to unmount (& destroy) all devices defined by disko.devices
              Does not ask for confirmation! Depracated in favor of _destroy
            '';
            default = ''
              umount -Rv "${rootMountPoint}" || :

              # shellcheck disable=SC2043,2041
              for dev in ${
                toString (
                  lib.catAttrs "device" (lib.attrValues (lib.filterAttrs (name: disk: disk.destroy) devices.disk))
                )
              };
              do
                $BASH ${../disk-deactivate}/disk-deactivate "$dev"
              done

            '';
          };
          _destroy = lib.mkOption {
            internal = true;
            type = lib.types.str;
            description = ''
              The script to unmount (& destroy) all devices defined by disko.devices
            '';
            default =
              let
                disksToWipe = lib.attrValues (lib.filterAttrs (name: disk: disk.destroy) devices.disk);
                selectedDisks = lib.escapeShellArgs (lib.catAttrs "device" disksToWipe);
              in
              ''
                if [ "$1" != "--yes-wipe-all-disks" ]; then
                  echo "WARNING: This will destroy all data on the disks defined in disko.devices, which are:"
                  echo
                  # shellcheck disable=SC2043,2041
                  for dev in ${selectedDisks}; do
                    echo "  - $dev"
                  done
                  echo
                  echo "    (If you want to skip this dialogue, pass --yes-wipe-all-disks)"
                  echo
                  echo "Are you sure you want to wipe the devices listed above?"
                  read -rp "Type 'yes' to continue, anything else to abort: " confirmation

                  if [ "$confirmation" != "yes" ]; then
                    echo "Aborted."
                    exit 1
                  fi
                fi

                umount -Rv "${rootMountPoint}" || :

                # shellcheck disable=SC2043,2041
                for dev in ${toString (lib.catAttrs "device" disksToWipe)}; do
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
              with lib;
              let
                sortedDeviceList = diskoLib.sortDevicesByDependencies (cfg.config._meta.deviceDependencies or { }
                ) devices;
              in
              ''
                set -efux

                disko_devices_dir=$(mktemp -d)
                trap 'rm -rf "$disko_devices_dir"' EXIT
                mkdir -p "$disko_devices_dir"

                ${concatMapStrings (dev: (attrByPath (dev ++ [ "_create" ]) { } devices)) sortedDeviceList}
              '';
          };
          _mount = lib.mkOption {
            internal = true;
            type = lib.types.str;
            description = ''
              The script to mount all devices defined by disko.devices
            '';
            default =
              with lib;
              let
                mountOrder = pipe cfg.config._config.fileSystems.contents [
                  (foldl' recursiveUpdate { })
                  (mapAttrsToList (
                    mountPoint: value:
                    value
                    // {
                      mountPoint = value.mountPoint or mountPoint;
                      depends = [ ];
                    }
                  ))
                  (toposort diskoLib.fsBefore)
                  (getAttr "result")
                  (map (getAttr "mountPoint"))
                ];

                fsMounts = diskoLib.deepMergeMap (dev: dev._mount.fs or { }) (
                  flatten (map attrValues (attrValues devices))
                );

                sortedDeviceList = diskoLib.sortDevicesByDependencies (cfg.config._meta.deviceDependencies or { }
                ) devices;
              in
              ''
                set -efux
                # first create the necessary devices
                ${concatMapStrings (dev: (attrByPath (dev ++ [ "_mount" ]) { } devices).dev or "") sortedDeviceList}

                # and then mount the filesystems in alphabetical order
                ${concatStrings (attrVals mountOrder fsMounts)}
              '';
          };
          _unmount = lib.mkOption {
            internal = true;
            type = lib.types.str;
            description = ''
              The script to unmount all devices defined by disko.devices
            '';
            default =
              with lib;
              let
                fsMounts = diskoLib.deepMergeMap (dev: dev._unmount.fs or { }) (
                  flatten (map attrValues (attrValues devices))
                );
                sortedDeviceList = diskoLib.sortDevicesByDependencies (cfg.config._meta.deviceDependencies or { }
                ) devices;
              in
              ''
                set -efux
                # first unmount the filesystems in reverse alphabetical order
                ${concatStrings (lib.reverseList (attrValues fsMounts))}

                # Than close the devices
                ${concatMapStrings (dev: (attrByPath (dev ++ [ "_unmount" ]) { } devices).dev or "") (
                  lib.reverseList sortedDeviceList
                )}
              '';
          };
          _disko = lib.mkOption {
            internal = true;
            type = lib.types.str;
            description = ''
              The script to umount, create and mount all devices defined by disko.devices
              Deprecated in favor of _destroyFormatMount
            '';
            default = ''
              ${cfg.config._legacyDestroy}
              ${cfg.config._create}
              ${cfg.config._mount}
            '';
          };
          _destroyFormatMount = lib.mkOption {
            internal = true;
            type = lib.types.str;
            description = ''
              The script to unmount, create and mount all devices defined by disko.devices
            '';
            default = ''
              ${cfg.config._destroy}
              ${cfg.config._create}
              ${cfg.config._mount}
            '';
          };
          _formatMount = lib.mkOption {
            internal = true;
            type = lib.types.str;
            description = ''
              The script to create and mount all devices defined by disko.devices, without wiping the disks first
            '';
            default = ''
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
              with lib;
              let
                configKeys = flatten (
                  map attrNames (flatten (map (dev: dev._config) (flatten (map attrValues (attrValues devices)))))
                );
                collectedConfigs = flatten (map (dev: dev._config) (flatten (map attrValues (attrValues devices))));
              in
              genAttrs configKeys (key: mkMerge (catAttrs key collectedConfigs));
          };
        };
      }
    );

    # import all the types from the types directory
    types = lib.listToAttrs (
      map (
        file: lib.nameValuePair (lib.removeSuffix ".nix" file) (diskoLib.mkSubType (./types + "/${file}"))
      ) (lib.attrNames (builtins.readDir ./types))
    );

    # render types into an json serializable format
    serializeType =
      type:
      let
        options = lib.filter (x: !lib.hasPrefix "_" x) (lib.attrNames type.options);
      in
      lib.listToAttrs (map (option: lib.nameValuePair option type.options.${option}) options);

    typesSerializerLib = {
      rootMountPoint = "";
      options = null;
      config = {
        _module = {
          args.name = "<self.name>";
          args._parent.name = "<parent.name>";
          args._parent.type = "<parent.type>";
        };
        name = "<config.name>";
      };
      parent = { };
      device = "/dev/<device>";
      # Spoof part of nixpkgs/lib to analyze the types
      lib = lib // {
        mkOption = option: {
          inherit (option) type;
          description = option.description or null;
          default = option.defaultText or option.default or null;
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
          oneOf = types: {
            type = "oneOf";
            inherit types;
          };
          either = t1: t2: {
            type = "oneOf";
            types = [
              t1
              t2
            ];
          };
          enum = choices: {
            type = "enum";
            inherit choices;
          };
          anything = "anything";
          nonEmptyStr = "str";
          strMatching = _: "str";
          str = "str";
          bool = "bool";
          int = "int";
          submodule =
            x:
            x {
              inherit (diskoLib.typesSerializerLib) lib config options;
              name = "<self.name>";
            };
        };
      };
      diskoLib = {
        optionTypes.absolute-pathname = "absolute-pathname";
        # Spoof these types to avoid infinite recursion
        deviceType = _: "<deviceType>";
        partitionType = _: "<partitionType>";
        subType =
          { types, ... }:
          {
            type = "oneOf";
            types = lib.attrNames types;
          };
        mkCreateOption = option: "_create";
      };
    };

    jsonTypes =
      lib.listToAttrs (
        map (
          file:
          lib.nameValuePair (lib.removeSuffix ".nix" file) (
            diskoLib.serializeType (import (./types + "/${file}") diskoLib.typesSerializerLib)
          )
        ) (lib.filter (name: lib.hasSuffix ".nix" name) (lib.attrNames (builtins.readDir ./types)))
      )
      // {
        partitionType = {
          type = "oneOf";
          types = lib.attrNames diskoLib._partitionTypes;
        };
        deviceType = {
          type = "oneOf";
          types = lib.attrNames diskoLib._deviceTypes;
        };
      };

    binfmt = import ./binfmt.nix;
  } // outputs;
in
diskoLib
