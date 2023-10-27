{ config, options, lib, diskoLib, parent, device, ... }:
let
  sortedPartitions = lib.sort (x: y: x.priority < y.priority) (lib.attrValues config.partitions);
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
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }@partition: {
        options = {
          type = lib.mkOption {
            type = lib.types.strMatching "[A-Fa-f0-9]{4}";
            default = "8300";
            description = "Filesystem type to use, run sgdisk -L to see what is available";
          };
          device = lib.mkOption {
            type = lib.types.str;
            default =
              if config._parent.type == "mdadm" then
              # workaround because mdadm partlabel do not appear in /dev/disk/by-partlabel
                "/dev/disk/by-id/md-name-any:${config._parent.name}-part${toString partition.config._index}"
              else
                "/dev/disk/by-partlabel/${partition.config.label}";
            description = "Device to use for the partition";
          };
          priority = lib.mkOption {
            type = lib.types.int;
            default = if (partition.config.size or "" == "100%") then 9001 else 1000;
            description = "Priority of the partition, smaller values are created first";
          };
          name = lib.mkOption {
            type = lib.types.str;
            description = "Name of the partition";
            default = name;
          };
          label = lib.mkOption {
            type = lib.types.str;
            default = "${config._parent.type}-${config._parent.name}-${partition.config.name}";
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
          start = lib.mkOption {
            type = lib.types.str;
            default = "0";
            description = "Start of the partition, in sgdisk format, use 0 for next available range";
          };
          end = lib.mkOption {
            type = lib.types.str;
            default = if partition.config.size == "100%" then "-0" else "+${partition.config.size}";
            description = ''
              End of the partition, in sgdisk format.
              Use + for relative sizes from the partitions start
              or - for relative sizes from the disks end
            '';
          };
          content = diskoLib.partitionType { parent = config; device = partition.config.device; };
          _index = lib.mkOption {
            internal = true;
            default = diskoLib.indexOf (x: x.name == partition.config.name) sortedPartitions 0;
          };
        };
      }));
      default = [ ];
      description = "Attrs of partitions to add to the partition table";
    };
    _parent = lib.mkOption {
      internal = true;
      default = parent;
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = dev:
        lib.foldr lib.recursiveUpdate { } (map
          (partition:
            lib.optionalAttrs (partition.content != null) (partition.content._meta dev)
          )
          (lib.attrValues config.partitions));
      description = "Metadata";
    };
    _update = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        ${lib.concatStrings (map (partition: ''
          if ! sgdisk \
            --info=${toString partition._index} \
            ${config.device} > /dev/null 2>&1
          then
            sgdisk \
              --set-alignment=2048 \
              --align-end \
              --new=${toString partition._index}:${partition.start}:${partition.end} \
              --change-name=${toString partition._index}:${partition.label} \
              --typecode=${toString partition._index}:${partition.type} \
              ${config.device}
            # ensure /dev/disk/by-path/..-partN exists before continuing
            partprobe ${config.device}
            udevadm trigger --subsystem-match=block
            udevadm settle
            ${lib.optionalString (partition.content != null) partition.content._create}
          else
            echo "not updating partition ${partition.label} of device ${config.device}"
            ${lib.optionalString (partition.content != null) partition.content._update}
          fi
        '') sortedPartitions)}

      '';
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        ${lib.concatStrings (map (partition: ''
          sgdisk \
            --set-alignment=2048 \
            --align-end \
            --new=${toString partition._index}:${partition.start}:${partition.end} \
            --change-name=${toString partition._index}:${partition.label} \
            --typecode=${toString partition._index}:${partition.type} \
            ${config.device}
          # ensure /dev/disk/by-path/..-partN exists before continuing
          partprobe ${config.device}
          udevadm trigger --subsystem-match=block
          udevadm settle
          ${lib.optionalString (partition.content != null) partition.content._create}
        '') sortedPartitions)}

      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default =
        let
          partMounts = lib.foldr lib.recursiveUpdate { } (map
            (partition:
              lib.optionalAttrs (partition.content != null) partition.content._mount
            )
            (lib.attrValues config.partitions));
        in
        {
          dev = partMounts.dev or "";
          fs = partMounts.fs or { };
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = (map
        (partition:
          lib.optional (partition.content != null) partition.content._config
        )
        (lib.attrValues config.partitions))
      ++ (lib.optional (lib.any (part: part.type == "EF02") (lib.attrValues config.partitions)) {
        boot.loader.grub.devices = [ config.device ];
      });
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs:
        [
          pkgs.gptfdisk
          pkgs.systemdMinimal
          pkgs.parted # for partprobe
        ] ++ lib.flatten (map
          (partition:
            lib.optional (partition.content != null) (partition.content._pkgs pkgs)
          )
          (lib.attrValues config.partitions));
      description = "Packages";
    };
  };
}
