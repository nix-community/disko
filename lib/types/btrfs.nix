{
  config,
  options,
  diskoLib,
  lib,
  rootMountPoint,
  parent,
  device,
  ...
}:
let
  btrfsPerMountOptionKeys = [
    "ro"
    "rw"
    "nosuid"
    "suid"
    "dev"
    "nodev"
    "exec"
    "noexec"
    "atime"
    "lazytime"
    "noatime"
    "nolazytime"
    "norelatime"
    "nostrictatime"
    "relatime"
    "strictatime"
  ];

  getMountOptionKey = option: builtins.head (lib.splitString "=" option);

  isIgnoredMountOption =
    option:
    (
      let
        optionKey = lib.toLower (getMountOptionKey option);
      in
      optionKey == "defaults" || optionKey == "subvol" || optionKey == "x-mount.mkdir"
    );

  isWhitelistedPerMountOption =
    option: lib.elem (lib.toLower (getMountOptionKey option)) btrfsPerMountOptionKeys;

  fsWideMountOptionSet =
    mountOptions:
    lib.sort lib.lessThan (
      lib.unique (
        lib.filter (
          option: !(isIgnoredMountOption option || isWhitelistedPerMountOption option)
        ) mountOptions
      )
    );

  swapType = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            size = lib.mkOption {
              type = lib.types.strMatching "^([0-9]+[KMGTP])?$";
              description = "Size of the swap file (e.g. 2G)";
            };

            path = lib.mkOption {
              type = lib.types.str;
              default = name;
              description = "Path to the swap file (relative to the mountpoint)";
            };

            priority = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = ''
                Specify the priority of the swap file. Priority is a value between 0 and 32767.
                Higher numbers indicate higher priority.
                null lets the kernel choose a priority, which will show up as a negative value.
              '';
            };

            options = lib.mkOption {
              type = lib.types.listOf lib.types.nonEmptyStr;
              default = [ "defaults" ];
              example = [ "nofail" ];
              description = "Options used to mount the swap.";
            };
          };
        }
      )
    );
    default = { };
    description = "Swap files";
  };

  swapConfig =
    { mountpoint, swap }:
    {
      swapDevices = builtins.map (file: {
        device = "${mountpoint}/${file.path}";
        inherit (file) priority options;
      }) (lib.attrValues swap);
    };

  swapCreate =
    mountpoint: swap:
    lib.concatMapStringsSep "\n" (file: ''
      if ! test -e "${mountpoint}/${file.path}"; then
        btrfs filesystem mkswapfile --size ${file.size} "${mountpoint}/${file.path}"
      fi
    '') (lib.attrValues swap);

in
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "btrfs" ];
      internal = true;
      description = "Type";
    };
    device = lib.mkOption {
      type = lib.types.str;
      default = device;
      description = "Device to use";
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments";
    };
    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "defaults" ];
      description = ''
        A list of options to pass to mount.
        Btrfs mount options are largely filesystem-wide; by default disko enforces
        consistency for mounted subvolumes on non-whitelisted options.
      '';
    };
    warnOnInconsistentMountOptions = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Warn when mounted subvolumes use inconsistent non-whitelisted Btrfs mount options.
        Set to false to silence these warnings.
      '';
    };
    enforceConsistentMountOptions = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Throw an evaluation error when mounted subvolumes use inconsistent non-whitelisted
        Btrfs mount options.
      '';
    };
    subvolumes = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { config, ... }:
          {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                default = config._module.args.name;
                description = "Name of the BTRFS subvolume.";
              };
              type = lib.mkOption {
                type = lib.types.enum [ "btrfs_subvol" ];
                default = "btrfs_subvol";
                internal = true;
                description = "Type";
              };
              extraArgs = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Extra arguments";
              };
              mountOptions = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ "defaults" ];
                description = "Options to pass to mount";
              };
              mountpoint = lib.mkOption {
                type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
                default = null;
                description = "Location to mount the subvolume to.";
              };
              swap = swapType;
            };
          }
        )
      );
      default = { };
      description = "Subvolumes to define for BTRFS.";
    };
    mountpoint = lib.mkOption {
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = "A path to mount the BTRFS filesystem to.";
    };
    swap = swapType;
    _parent = lib.mkOption {
      internal = true;
      default = parent;
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = _dev: { };
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        # create the filesystem only if the device seems empty
        if ! (blkid "${config.device}" -o export | grep -q '^TYPE='); then
          mkfs.btrfs "${config.device}" ${toString config.extraArgs}
        fi
        ${lib.optionalString (config.swap != { } || config.subvolumes != { }) ''
          if (blkid "${config.device}" -o export | grep -q '^TYPE=btrfs$'); then
            ${lib.optionalString (config.swap != { }) ''
              (
                MNTPOINT=$(mktemp -d)
                mount ${device} "$MNTPOINT" -o subvol=/
                trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
                ${swapCreate "$MNTPOINT" config.swap}
              )
            ''}
            ${lib.concatMapStrings (subvol: ''
              (
                MNTPOINT=$(mktemp -d)
                mount "${config.device}" "$MNTPOINT" -o subvol=/
                trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
                SUBVOL_ABS_PATH="$MNTPOINT/${subvol.name}"
                mkdir -p "$(dirname "$SUBVOL_ABS_PATH")"
                if ! btrfs subvolume show "$SUBVOL_ABS_PATH" > /dev/null 2>&1; then
                  btrfs subvolume create "$SUBVOL_ABS_PATH" ${toString subvol.extraArgs}
                fi
                ${swapCreate "$SUBVOL_ABS_PATH" subvol.swap}
              )
            '') (lib.attrValues config.subvolumes)}
          fi
        ''}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default =
        let
          subvolDefaults = (options.subvolumes.type.getSubOptions [ ]).mountOptions.default;

          mountedSubvolumes = map (name: config.subvolumes.${name}) (
            lib.filter (name: config.subvolumes.${name}.mountpoint != null) (
              builtins.attrNames config.subvolumes
            )
          );

          baseFsOpts = fsWideMountOptionSet config.mountOptions;
          baseFsOptsByKey = builtins.listToAttrs (
            map (opt: {
              name = lib.toLower (getMountOptionKey opt);
              value = opt;
            }) baseFsOpts
          );

          # Subvolumes using the default mountOptions inherit the top-level Btrfs
          # mountOptions for the consistency check.
          subvolFsOverrides =
            subvol:
            if subvol.mountOptions == subvolDefaults then [ ] else fsWideMountOptionSet subvol.mountOptions;

          optsByKey =
            opts:
            builtins.listToAttrs (
              map (opt: {
                name = lib.toLower (getMountOptionKey opt);
                value = opt;
              }) opts
            );

          # Effective filesystem-wide options are computed by overlaying subvolume
          # overrides on top of the canonical top-level filesystem options by key.
          mergedFsOpts =
            subvol:
            lib.sort lib.lessThan (
              builtins.attrValues (baseFsOptsByKey // optsByKey (subvolFsOverrides subvol))
            );

          mountedSubvols = map (subvol: {
            cfg = subvol;
            requested = subvolFsOverrides subvol;
            eff = mergedFsOpts subvol;
          }) mountedSubvolumes;

          isConsistentOverrides =
            requestedOpts:
            lib.all (
              opt:
              let
                optKey = lib.toLower (getMountOptionKey opt);
              in
              builtins.hasAttr optKey baseFsOptsByKey && baseFsOptsByKey.${optKey} == opt
            ) requestedOpts;

          inconsistentSubvols = lib.filter (subvol: !(isConsistentOverrides subvol.requested)) mountedSubvols;

          fmtFsOpts = opts: if opts == [ ] then "(none)" else lib.concatStringsSep ", " opts;

          inconsistentMsg =
            "Inconsistent Btrfs mountOptions across mounted subvolumes: "
            + "${lib.concatStringsSep ", " (map (subvol: subvol.cfg.name) inconsistentSubvols)}. "
            + "Offending effective filesystem-wide option sets: "
            + "${
              lib.concatStringsSep "; " (
                map (subvol: "${subvol.cfg.name}=[${fmtFsOpts subvol.eff}]") inconsistentSubvols
              )
            }. "
            + "Canonical top-level filesystem-wide option set: "
            + "[${fmtFsOpts baseFsOpts}]. "
            + "Btrfs mount options are largely filesystem-wide, so differing filesystem-wide options "
            + "across subvolume mounts are not deterministic. Only per-mount flags are safely allowed "
            + "(ro/rw, nosuid/suid, nodev/dev, noexec/exec, and atime variants).";

          subvolMounts = lib.concatMapAttrs (
            _: subvol:
            lib.warnIf (subvol.mountOptions != subvolDefaults && subvol.mountpoint == null)
              "Subvolume ${subvol.name} has mountOptions but no mountpoint. See upgrade guide (2023-07-09 121df48)."
              lib.optionalAttrs
              (subvol.mountpoint != null)
              {
                ${subvol.mountpoint} = ''
                  if ! findmnt "${config.device}" "${rootMountPoint}${subvol.mountpoint}" > /dev/null 2>&1; then
                    mount "${config.device}" "${rootMountPoint}${subvol.mountpoint}" \
                    ${
                      lib.concatMapStringsSep " " (opt: "-o ${opt}") (subvol.mountOptions ++ [ "subvol=${subvol.name}" ])
                    } \
                    -o X-mount.mkdir
                  fi
                '';
              }
          ) config.subvolumes;

          guardedSubvolMounts =
            if inconsistentSubvols == [ ] then
              subvolMounts
            else if config.enforceConsistentMountOptions then
              throw inconsistentMsg
            else if config.warnOnInconsistentMountOptions then
              lib.warn inconsistentMsg subvolMounts
            else
              subvolMounts;
        in
        {
          fs =
            guardedSubvolMounts
            // lib.optionalAttrs (config.mountpoint != null) {
              ${config.mountpoint} = ''
                if ! findmnt "${config.device}" "${rootMountPoint}${config.mountpoint}" > /dev/null 2>&1; then
                  mount "${config.device}" "${rootMountPoint}${config.mountpoint}" \
                  ${lib.concatMapStringsSep " " (opt: "-o ${opt}") config.mountOptions} \
                  -o X-mount.mkdir
                fi
              '';
            };
        };
    };
    _unmount = diskoLib.mkUnmountOption {
      inherit config options;
      default =
        let
          subvolMounts = lib.concatMapAttrs (
            _: subvol:
            lib.optionalAttrs (subvol.mountpoint != null) {
              ${subvol.mountpoint} = ''
                if findmnt "${config.device}" "${rootMountPoint}${subvol.mountpoint}" > /dev/null 2>&1; then
                  umount "${rootMountPoint}${subvol.mountpoint}"
                fi
              '';
            }
          ) config.subvolumes;
        in
        {
          fs =
            subvolMounts
            // lib.optionalAttrs (config.mountpoint != null) {
              ${config.mountpoint} = ''
                if findmnt "${config.device}" "${rootMountPoint}${config.mountpoint}" > /dev/null 2>&1; then
                  umount "${rootMountPoint}${config.mountpoint}"
                fi
              '';
            };
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = [
        (map (
          subvol:
          lib.optional (subvol.mountpoint != null) {
            fileSystems.${subvol.mountpoint} = {
              device = config.device;
              fsType = "btrfs";
              options = subvol.mountOptions ++ [ "subvol=${subvol.name}" ];
            };
          }
        ) (lib.attrValues config.subvolumes))
        (lib.optional (config.mountpoint != null) {
          fileSystems.${config.mountpoint} = {
            device = config.device;
            fsType = "btrfs";
            options = config.mountOptions;
          };
        })
        (map (
          subvol:
          swapConfig {
            inherit (subvol) mountpoint swap;
          }
        ) (lib.attrValues config.subvolumes))
        (swapConfig {
          inherit (config) mountpoint swap;
        })
      ];
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [
        pkgs.btrfs-progs
        pkgs.gnugrep
      ];
      description = "Packages";
    };
  };
}
