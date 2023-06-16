{ config, options, lib, diskoLib, parent, ... }@args:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "gpt" ];
      internal = true;
      description = "Partition table";
    };
    partitions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }@partition: {
        options = {
          type = lib.mkOption {
            type = lib.types.strMatching "[A-Fa-f0-9]{4}";
            default = "8300";
            description = "Filesystem type to use, run sgdisk -L to see what is available";
          };
          priority = lib.mkOption {
            type = lib.types.int;
            default = 1000;
            description = "Priority of the partition, higher priority partitions are created first";
          };
          name = lib.mkOption {
            type = lib.types.str;
            description = "Name of the partition";
            default = name;
          };
          label = lib.mkOption {
            type = lib.types.str;
            default = "${config._parent.type}-${config._parent.name}-${partition.name}";
          };
          start = lib.mkOption {
            type = lib.types.str;
            default = "0";
            description = "Start of the partition, in sgdisk format, use 0 for next available range";
          };
          end = lib.mkOption {
            type = lib.types.str;
            description = ''
              End of the partition, in sgdisk format.
              Use + for relative sizes from the partitons start
              or - for relative sizes from the disks end
            '';
          };
          content = diskoLib.partitionType { parent = config; };
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
        lib.foldr lib.recursiveUpdate { } (lib.imap
          (index: partition:
            lib.optionalAttrs (partition.content != null) (partition.content._meta dev)
          )
          (lib.attrValues config.partitions));
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = { dev }: ''
        ${lib.concatStrings (lib.imap (index: partition: ''
          sgdisk \
            --new=${toString index}:${partition.start}:${partition.end} \
            --change-name=${toString index}:${partition.label} \
            --typecode=${toString index}:${partition.type} \
            ${dev}
          # ensure /dev/disk/by-path/..-partN exists before continuing
          udevadm trigger --subsystem-match=block; udevadm settle
          ${lib.optionalString (partition.content != null) (partition.content._create { dev = "/dev/disk/by-partlabel/${partition.label}"; })}
        '') (lib.attrValues config.partitions))}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { dev }:
        let
          partMounts = lib.foldr lib.recursiveUpdate { } (lib.imap
            (index: partition:
              lib.optionalAttrs (partition.content != null) (partition.content._mount { dev = "/dev/disk/by-partlabel/${partition.label}"; })
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
      default = dev:
        lib.imap
          (index: partition:
            lib.optional (partition.content != null) (partition.content._config "/dev/disk/by-partlabel/${partition.label}")
          )
          (lib.attrValues config.partitions);
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs:
        [ pkgs.gptfdisk pkgs.systemdMinimal ] ++ lib.flatten (map
          (partition:
            lib.optional (partition.content != null) (partition.content._pkgs pkgs)
          )
          (lib.attrValues config.partitions));
      description = "Packages";
    };
  };
}
