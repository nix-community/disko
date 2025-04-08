{
  config,
  options,
  lib,
  diskoLib,
  parent,
  device,
  ...
}:
let
  sortedPartitions = lib.sort (x: y: x.priority < y.priority) (lib.attrValues config.partitions);
  sortedHybridPartitions = lib.filter (p: p.hybrid != null) sortedPartitions;
in
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "gpt" ];
      internal = true;
      description = "Partition table";
    };
    device = lib.mkOption {
      type = lib.types.str;
      default = device;
      description = "Device to use for the partition table";
    };
    partitions = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }@partition:
          {
            options = {
              type = lib.mkOption {
                type =
                  let
                    hexPattern = len: "[A-Fa-f0-9]{${toString len}}";
                  in
                  lib.types.either (lib.types.strMatching (hexPattern 4)) (
                    lib.types.strMatching (
                      lib.concatMapStringsSep "-" hexPattern [
                        8
                        4
                        4
                        4
                        12
                      ]
                    )
                  );
                default =
                  if partition.config.content != null && partition.config.content.type == "swap" then
                    "8200"
                  else
                    "8300";
                defaultText = ''8300 (Linux filesystem) normally, 8200 (Linux swap) if content.type is "swap"'';
                description = ''
                  Filesystem type to use.
                  This can either be an sgdisk-specific short code (run sgdisk -L to see what is available),
                  or a fully specified GUID (see https://en.wikipedia.org/wiki/GUID_Partition_Table#Partition_type_GUIDs).
                '';
              };
              device = lib.mkOption {
                type = lib.types.str;
                default =
                  if partition.config.uuid != null then
                    "/dev/disk/by-partuuid/${partition.config.uuid}"
                  else if config._parent.type == "mdadm" then
                    # workaround because mdadm partlabel do not appear in /dev/disk/by-partlabel
                    "/dev/disk/by-id/md-name-any:${config._parent.name}-part${toString partition.config._index}"
                  else
                    "/dev/disk/by-partlabel/${diskoLib.hexEscapeUdevSymlink partition.config.label}";
                defaultText = ''
                  if `uuid` is provided:
                    /dev/disk/by-partuuid/''${partition.config.uuid}

                  otherwise, if the parent is an mdadm device:
                    /dev/disk/by-id/md-name-any:''${config._parent.name}-part''${toString partition.config._index}

                  otherwise:
                    /dev/disk/by-partlabel/''${diskoLib.hexEscapeUdevSymlink partition.config.label}
                '';
                description = "Device to use for the partition";
              };
              priority = lib.mkOption {
                type = lib.types.int;
                default =
                  if partition.config.size or "" == "100%" then
                    9001
                  else if partition.config.type == "EF02" then
                    # Boot partition should be created first, because some BIOS implementations require it.
                    # Priority defaults to 100 here to support any potential use-case for placing partitions prior to EF02
                    100
                  else
                    1000;
                defaultText = ''
                  1000: normal partitions
                  9001: partitions with 100% size
                  100: boot partitions (EF02)
                '';
                description = "Priority of the partition, smaller values are created first";
              };
              name = lib.mkOption {
                type = lib.types.str;
                description = "Name of the partition";
                default = name;
              };
              uuid = lib.mkOption {
                type = lib.types.nullOr (
                  lib.types.strMatching "[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}"
                );
                default = null;
                defaultText = "`null` - generate a UUID when creating the partition";
                example = "809b3a2b-828a-4730-95e1-75b6343e415a";
                description = ''
                  The UUID (also known as GUID) of the partition. Note that this is distinct from the UUID of the filesystem.

                  You can generate a UUID with the command `uuidgen -r`.
                '';
              };
              label = lib.mkOption {
                type = lib.types.str;
                default =
                  let
                    # 72 bytes is the maximum length of a GPT partition name
                    # the labels seem to be in UTF-16, so 2 bytes per character
                    limit = 36;
                    label = "${config._parent.type}-${config._parent.name}-${partition.config.name}";
                  in
                  if (lib.stringLength label) > limit then
                    builtins.substring 0 limit (builtins.hashString "sha256" label)
                  else
                    label;
                defaultText = ''
                  ''${config._parent.type}-''${config._parent.name}-''${partition.config.name}

                  or a truncated hash of the above if it is longer than 36 characters
                '';
              };
              size = lib.mkOption {
                type = lib.types.either (lib.types.enum [ "100%" ]) (lib.types.strMatching "[0-9]+[KMGTP]?");
                default = "0";
                description = ''
                  Size of the partition, in sgdisk format.
                  sets end automatically with the + prefix
                  can be 100% for the whole remaining disk, will be done last in that case.
                '';
              };
              alignment = lib.mkOption {
                type = lib.types.int;
                default =
                  if
                    (
                      builtins.substring (builtins.stringLength partition.config.start - 1) 1 partition.config.start
                      == "s"
                      || (
                        builtins.substring (builtins.stringLength partition.config.end - 1) 1 partition.config.end == "s"
                      )
                    )
                  then
                    1
                  else
                    0;
                defaultText = "1 if the unit of start or end is sectors, 0 otherwise";
                description = "Alignment of the partition, if sectors are used as start or end it can be aligned to 1";
              };
              start = lib.mkOption {
                type = lib.types.str;
                default = "0";
                description = "Start of the partition, in sgdisk format, use 0 for next available range";
              };
              end = lib.mkOption {
                type = lib.types.str;
                default = if partition.config.size == "100%" then "-0" else "+${partition.config.size}";
                defaultText = ''
                  if partition.config.size == "100%" then "-0" else "+''${partition.config.size}";
                '';
                description = ''
                  End of the partition, in sgdisk format.
                  Use + for relative sizes from the partitions start
                  or - for relative sizes from the disks end
                '';
              };
              content = diskoLib.partitionType {
                parent = config;
                device = partition.config.device;
              };
              hybrid = lib.mkOption {
                type = lib.types.nullOr (
                  lib.types.submodule (
                    { ... }@hp:
                    {
                      options = {
                        mbrPartitionType = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "MBR type code";
                        };
                        mbrBootableFlag = lib.mkOption {
                          type = lib.types.bool;
                          default = false;
                          description = "Set the bootable flag (aka the active flag) on any or all of your hybridized partitions";
                        };
                        _create = diskoLib.mkCreateOption {
                          inherit config options;
                          default = ''
                            ${lib.optionalString (hp.config.mbrPartitionType != null) ''
                              sfdisk --label-nested dos --part-type "${parent.device}" ${(toString partition.config._index)} ${hp.config.mbrPartitionType}
                              udevadm trigger --subsystem-match=block
                              udevadm settle --timeout 120
                            ''}
                            ${lib.optionalString hp.config.mbrBootableFlag ''
                              sfdisk --label-nested dos --activate "${parent.device}" ${(toString partition.config._index)}
                            ''}
                          '';
                        };
                      };
                    }
                  )
                );
                default = null;
                description = "Entry to add to the Hybrid MBR table";
              };
              _index = lib.mkOption {
                type = lib.types.int;
                internal = true;
                default = diskoLib.indexOf (x: x.name == partition.config.name) sortedPartitions 0;
                defaultText = null;
              };
            };
          }
        )
      );
      default = { };
      description = "Attrs of partitions to add to the partition table";
    };
    efiGptPartitionFirst = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Place EFI GPT (0xEE) partition first in MBR (good for GRUB)";
    };
    _parent = lib.mkOption {
      internal = true;
      default = parent;
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default =
        dev:
        lib.foldr lib.recursiveUpdate { } (
          map (partition: lib.optionalAttrs (partition.content != null) (partition.content._meta dev)) (
            lib.attrValues config.partitions
          )
        );
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        if ! blkid "${config.device}" >&2; then
          sgdisk --clear "${config.device}"
        fi
        ${lib.concatMapStrings (
          partition:
          let
            args = ''
              --partition-guid="${toString partition._index}:${
                if partition.uuid == null then "R" else partition.uuid
              }" \
              --change-name="${toString partition._index}:${partition.label}" \
              --typecode=${toString partition._index}:${partition.type} \
              "${config.device}" \
            '';
            createArgs = ''
              --align-end ${
                lib.optionalString (
                  partition.alignment != 0
                ) ''--set-alignment=${builtins.toString partition.alignment}''
              } \
              --new=${toString partition._index}:${partition.start}:${partition.end} \
            '';
          in
          ''
            # try to create the partition, if it fails, try to change the type and name
            if ! sgdisk ${createArgs} ${args}
            then
              sgdisk ${args}
            fi
            # ensure /dev/disk/by-path/..-partN exists before continuing
            partprobe "${config.device}" || : # sometimes partprobe fails, but the partitions are still up2date
            udevadm trigger --subsystem-match=block
            udevadm settle --timeout 120
          ''
        ) sortedPartitions}

        ${lib.optionalString (sortedHybridPartitions != [ ]) (
          "sgdisk -h "
          + (lib.concatStringsSep ":" (map (p: (toString p._index)) sortedHybridPartitions))
          + (lib.optionalString (!config.efiGptPartitionFirst) ":EE ")
          + ''"${parent.device}"''
        )}
        ${lib.concatMapStrings (p: p.hybrid._create) sortedHybridPartitions}

        ${lib.concatStrings (
          map (partition: ''
            ${lib.optionalString (partition.content != null) partition.content._create}
          '') sortedPartitions
        )}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default =
        let
          partMounts = lib.foldr lib.recursiveUpdate { } (
            map (partition: lib.optionalAttrs (partition.content != null) partition.content._mount) (
              lib.attrValues config.partitions
            )
          );
        in
        {
          dev = partMounts.dev or "";
          fs = partMounts.fs or { };
        };
    };
    _unmount = diskoLib.mkUnmountOption {
      inherit config options;
      default =
        let
          partMounts = lib.foldr lib.recursiveUpdate { } (
            map (partition: lib.optionalAttrs (partition.content != null) partition.content._unmount) (
              lib.attrValues config.partitions
            )
          );
        in
        {
          dev = partMounts.dev or "";
          fs = partMounts.fs or { };
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default =
        (map (partition: lib.optional (partition.content != null) partition.content._config) (
          lib.attrValues config.partitions
        ))
        ++ (lib.optional (lib.any (part: part.type == "EF02") (lib.attrValues config.partitions)) {
          boot.loader.grub.devices = [ config.device ];
        });
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default =
        pkgs:
        [
          pkgs.gptfdisk
          pkgs.systemdMinimal
          pkgs.parted # for partprobe
        ]
        ++ lib.flatten (
          map (partition: lib.optional (partition.content != null) (partition.content._pkgs pkgs)) (
            lib.attrValues config.partitions
          )
        );
      description = "Packages";
    };
  };
}
