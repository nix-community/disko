# NixOS Module Options


## [`options.type`](types/lvm_pv.nix#L12)

Type

**Type:** `lib.types.enum [ "lvm_pv" ]`

## [`options.device`](types/lvm_pv.nix#L17)

Device

**Type:** `lib.types.str`

**Default:** `device`

## [`options.vg`](types/lvm_pv.nix#L22)

Volume group

**Type:** `lib.types.str`

## [`options._parent`](types/lvm_pv.nix#L26)

**Type:** `any`

**Default:** `parent`

## [`options._meta`](types/lvm_pv.nix#L30)

Metadata

**Type:** `lib.types.functionTo diskoLib.jsonType`

**Default:**

```nix
dev: {
  deviceDependencies.lvm_vg.${config.vg} = [ dev ];
}
```

## [`options._config`](types/lvm_pv.nix#L56)

NixOS configuration

**Type:** `any`

**Default:** `[ ]`

## [`options._pkgs`](types/lvm_pv.nix#L62)

Packages

**Type:** `lib.types.functionTo (lib.types.listOf lib.types.package)`

**Default:**

```nix
pkgs: [
  pkgs.gnugrep
  pkgs.lvm2
]
```

## [`options.name`](types/disk.nix#L10)

Device name

**Type:** `lib.types.str`

**Default:** `lib.replaceStrings [ "/" ] [ "_" ] config._module.args.name`

## [`options.destroy`](types/disk.nix#L25)

If false, disko will not wipe or destroy this disk's contents during the destroy stage

**Type:** `lib.types.bool`

**Default:** `true`

## [`options.imageName`](types/disk.nix#L30)


name of the image when disko images are created
is used as an argument to "qemu-img create ..."


**Type:** `lib.types.str`

**Default:** `config.name`

## [`options.imageSize`](types/disk.nix#L38)


size of the image when disko images are created
is used as an argument to "qemu-img create ..."


**Type:** `lib.types.strMatching "[0-9]+[KMGTP]?"`

**Default:** `"2G"`

## [`options.partitions`](types/gpt.nix#L26)

Attrs of partitions to add to the partition table

**Type:**

```nix
lib.types.attrsOf (
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
        attributes = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = [ ];
          description = ''
            GPT partition entry attributes, according to UEFI specification 
            2.10 (see https://uefi.org/specs/UEFI/2.10_A/05_GUID_Partition_Table_Format.html#defined-gpt-partition-entry-attributes)
            and `sgdisk`s man page:

            - 0: Required Partition (`sgdisk`: system partition)
            - 1: No Block IO Protocol (`sgdisk`: hide from EFI)
            - 2: Legacy BIOS Bootable
            - 3-47: Undefined and must be zero, reserved for future use
            - 48-63: Reserved for GUID specific use. The use of these bits 
              will vary depending on the partition type

            `sgdisk` describes some of the GUID-specific bits this way:
            - 60: read only
            - 62: hidden
            - 63: do not automount
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
)
```

**Default:** `{ }`

## [`options.efiGptPartitionFirst`](types/gpt.nix#L255)

Place EFI GPT (0xEE) partition first in MBR (good for GRUB)

**Type:** `lib.types.bool`

**Default:** `true`

## [`options.extraArgs`](types/filesystem.nix#L23)

Extra arguments

**Type:** `lib.types.listOf lib.types.str`

**Default:** `[ ]`

## [`options.mountOptions`](types/filesystem.nix#L28)

Options to pass to mount

**Type:** `lib.types.listOf lib.types.str`

**Default:** `[ "defaults" ]`

## [`options.mountpoint`](types/filesystem.nix#L33)

Path to mount the filesystem to

**Type:** `lib.types.nullOr diskoLib.optionTypes.absolute-pathname`

**Default:** `null`

## [`options.format`](types/filesystem.nix#L38)

Format of the filesystem

**Type:** `lib.types.str`

## [`options.keyFile`](types/luks.nix#L60)

DEPRECATED use passwordFile or settings.keyFile. Path to the key for encryption

**Type:** `lib.types.nullOr diskoLib.optionTypes.absolute-pathname`

**Default:** `null`

**Example:** `"/tmp/disk.key"`

## [`options.passwordFile`](types/luks.nix#L66)

Path to the file which contains the password for initial encryption

**Type:** `lib.types.nullOr diskoLib.optionTypes.absolute-pathname`

**Default:** `null`

**Example:** `"/tmp/disk.key"`

## [`options.askPassword`](types/luks.nix#L72)

Whether to ask for a password for initial encryption

**Type:** `lib.types.bool`

**Default:**

```nix
config.keyFile == null && config.passwordFile == null && (!config.settings ? "keyFile")
```

## [`options.settings`](types/luks.nix#L78)

LUKS settings (as defined in configuration.nix in boot.initrd.luks.devices.<name>)

**Type:** `lib.types.attrsOf lib.types.anything`

**Default:** `{ }`

**Example:**

```nix
''
  {
            keyFile = "/tmp/disk.key";
            keyFileSize = 2048;
            keyFileOffset = 1024;
            fallbackToPassword = true;
            allowDiscards = true;
          };
''
```

## [`options.additionalKeyFiles`](types/luks.nix#L92)

Path to additional key files for encryption

**Type:** `lib.types.listOf diskoLib.optionTypes.absolute-pathname`

**Default:** `[ ]`

**Example:** `[ "/tmp/disk2.key" ]`

## [`options.initrdUnlock`](types/luks.nix#L98)

Whether to add a boot.initrd.luks.devices entry for the specified disk.

**Type:** `lib.types.bool`

**Default:** `true`

## [`options.extraFormatArgs`](types/luks.nix#L103)

Extra arguments to pass to `cryptsetup luksFormat` when formatting

**Type:** `lib.types.listOf lib.types.str`

**Default:** `[ ]`

**Example:** `[ "--pbkdf argon2id" ]`

## [`options.extraOpenArgs`](types/luks.nix#L109)

Extra arguments to pass to `cryptsetup luksOpen` when opening

**Type:** `lib.types.listOf lib.types.str`

**Default:** `[ ]`

**Example:** `[ "--timeout 10" ]`

## [`options.level`](types/mdadm.nix#L21)

mdadm level

**Type:** `lib.types.int`

**Default:** `1`

## [`options.metadata`](types/mdadm.nix#L26)

Metadata

**Type:**

```nix
lib.types.enum [
  "1"
  "1.0"
  "1.1"
  "1.2"
  "default"
  "ddf"
  "imsm"
]
```

**Default:** `"default"`

## [`options.filesystem`](types/bcachefs.nix#L23)

Name of the bcachefs filesystem this partition belongs to.

**Type:** `lib.types.str`

**Example:** `"main_bcachefs_filesystem"`

## [`options.label`](types/bcachefs.nix#L38)


Label to use for this device.
This value is passed as the `--label` argument to the `bcachefs format` command when formatting the device.


**Type:** `lib.types.str`

**Default:** `""`

**Example:** `"group_a.sda2"`

## [`options.options`](types/zfs_volume.nix#L22)

Options to set for the dataset

**Type:** `lib.types.attrsOf lib.types.str`

**Default:** `{ }`

## [`options.size`](types/zfs_volume.nix#L39)

Size of the dataset

**Type:** `lib.types.nullOr lib.types.str`

**Default:** `null`

## [`options.discardPolicy`](types/swap.nix#L22)


Specify the discard policy for the swap device. If "once", then the
whole swap space is discarded at swapon invocation. If "pages",
asynchronous discard on freed pages is performed, before returning to
the available pages pool. With "both", both policies are activated.
See swapon(8) for more information.


**Type:**

```nix
lib.types.nullOr (
  lib.types.enum [
    "once"
    "pages"
    "both"
  ]
)
```

**Default:** `null`

**Example:** `"once"`

## [`options.priority`](types/swap.nix#L51)


Specify the priority of the swap device. Priority is a value between 0 and 32767.
Higher numbers indicate higher priority.
null lets the kernel choose a priority, which will show up as a negative value.


**Type:** `lib.types.nullOr lib.types.int`

**Default:** `null`

## [`options.randomEncryption`](types/swap.nix#L60)

Whether to randomly encrypt the swap

**Type:** `lib.types.bool`

**Default:** `false`

## [`options.resumeDevice`](types/swap.nix#L65)

Whether to use this as a boot.resumeDevice

**Type:** `lib.types.bool`

**Default:** `false`

## [`options._name`](types/zfs_fs.nix#L18)

Fully quantified name for dataset

**Type:** `lib.types.str`

**Default:** `"${config._parent.name}/${config.name}"`

## [`options._createFilesystem`](types/zfs_fs.nix#L63)

**Type:** `lib.types.bool`

**Default:** `true`

## [`swapType`](types/btrfs.nix#L12)

Swap files

**Type:**

```nix
lib.types.attrsOf (
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
)
```

**Default:** `{ }`

## [`options.subvolumes`](types/btrfs.nix#L93)

Subvolumes to define for BTRFS.

**Type:**

```nix
lib.types.attrsOf (
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
)
```

**Default:** `{ }`

## [`options.pool`](types/zfs.nix#L22)

Name of the ZFS pool

**Type:** `lib.types.str`

## [`options.fsType`](types/nodev.nix#L17)

File system type

**Type:** `lib.types.str`

## [`options.uuid`](types/bcachefs_filesystem.nix#L50)


The UUID of the bcachefs filesystem.
If not provided, a deterministic UUID will be generated based on the filesystem name.


**Type:**

```nix
lib.types.strMatching "[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}"
```

**Default:**

```nix
let
  # Generate a deterministic but random-looking UUID based on the filesystem name
  # This avoids the need for impure access to nixpkgs at evaluation time
  hash = builtins.hashString "sha256" "${config.name}";
  hexChars = builtins.substring 0 32 hash;
  p1 = builtins.substring 0 8 hexChars;
  p2 = builtins.substring 8 4 hexChars;
  p3 = builtins.substring 12 4 hexChars;
  p4 = builtins.substring 16 4 hexChars;
  p5 = builtins.substring 20 12 hexChars;
in
"${p1}-${p2}-${p3}-${p4}-${p5}"
```

**Example:** `"809b3a2b-828a-4730-95e1-75b6343e415a"`

## [`options.mode`](types/zpool.nix#L33)

Mode of the ZFS pool

**Type:**

```nix
(
  lib.types.oneOf [
    (lib.types.enum modeOptions)
    (lib.types.attrsOf (
      diskoLib.subType {
        types = {
          topology =
            let
              vdev = lib.types.submodule (
                { ... }:
                {
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
                }
              );
            in
            lib.types.submodule (
              { ... }:
              {
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
                    example = [
                      {
                        mode = "mirror";
                        members = [
                          "x"
                          "y"
                        ];
                      }
                      {
                        members = [ "z" ];
                      }
                    ];
                  };
                  spare = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = ''
                      A list of devices to use as hot spares. See
                      https://openzfs.github.io/openzfs-docs/man/master/7/zpoolconcepts.7.html#Hot_Spares
                      for details.
                    '';
                    example = [
                      "x"
                      "y"
                    ];
                  };
                  log = lib.mkOption {
                    type = lib.types.listOf vdev;
                    default = [ ];
                    description = ''
                      A list of vdevs used for the zfs intent log (ZIL). See
                      https://openzfs.github.io/openzfs-docs/man/master/7/zpoolconcepts.7.html#Intent_Log
                      for details.
                    '';
                    example = [
                      {
                        mode = "mirror";
                        members = [
                          "x"
                          "y"
                        ];
                      }
                      {
                        members = [ "z" ];
                      }
                    ];
                  };
                  dedup = lib.mkOption {
                    type = lib.types.listOf vdev;
                    default = [ ];
                    description = ''
                      A list of vdevs used for the deduplication table. See
                      https://openzfs.github.io/openzfs-docs/man/master/7/zpoolconcepts.7.html#dedup
                      for details.
                    '';
                    example = [
                      {
                        mode = "mirror";
                        members = [
                          "x"
                          "y"
                        ];
                      }
                      {
                        members = [ "z" ];
                      }
                    ];
                  };
                  special = lib.mkOption {
                    type = lib.types.either (lib.types.listOf vdev) (lib.types.nullOr vdev);
                    default = [ ];
                    description = ''
                      A list of vdevs used as special devices. See
                      https://openzfs.github.io/openzfs-docs/man/master/7/zpoolconcepts.7.html#special
                      for details.
                    '';
                    example = [
                      {
                        mode = "mirror";
                        members = [
                          "x"
                          "y"
                        ];
                      }
                      {
                        members = [ "z" ];
                      }
                    ];
                  };
                  cache = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = ''
                      A dedicated zfs cache device (L2ARC). See
                      https://openzfs.github.io/openzfs-docs/man/master/7/zpoolconcepts.7.html#Cache_Devices
                      for details.
                    '';
                    example = [
                      "x"
                      "y"
                    ];
                  };
                };
              }
            );
        };
        extraArgs.parent = config;
      }
    ))
  ]
)
```

**Default:** `""`

**Example:**

```nix
{
  mode = {
    topology = {
      type = "topology";
      vdev = [
        {
          # Members can be either specified by a full path or by a disk name
          # This is example uses the full path
          members = [ "/dev/disk/by-id/wwn-0x5000c500af8b2a14" ];
        }
      ];
      log = [
        {
          # Example using gpt partition labels
          # This expects an disk called `ssd` with a gpt partition called `zfs`
          #   disko.devices.disk.ssd = {
          #    type = "disk";
          #    device = "/dev/nvme0n1";
          #    content = {
          #      type = "gpt";
          #      partitions = {
          #        zfs = {
          #          size = "100%";
          #          content = {
          #            type = "zfs";
          #            # use your own pool name here
          #            pool = "zroot";
          #          };
          #        };
          #      };
          #    };
          #  };
          members = [ "ssd" ];
        }
      ];
    };
  };
}
```

## [`options.rootFsOptions`](types/zpool.nix#L235)

Options for the root filesystem

**Type:** `lib.types.attrsOf lib.types.str`

**Default:** `{ }`

## [`options.datasets`](types/zpool.nix#L250)

List of datasets to define

**Type:**

```nix
lib.types.attrsOf (
  diskoLib.subType {
    types = { inherit (diskoLib.types) zfs_fs zfs_volume; };
    extraArgs.parent = config;
  }
)
```

## [`options.lvs`](types/lvm_vg.nix#L33)

LVS for the volume group

**Type:**

```nix
lib.types.attrsOf (
  lib.types.submodule (
    { name, ... }@lv:
    {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Name of the logical volume";
        };
        priority = lib.mkOption {
          type = lib.types.int;
          default =
            (if lv.config.lvm_type == "thin-pool" then 501 else 1000)
            + (if lib.hasInfix "100%" lv.config.size then 251 else 0);
          defaultText = lib.literalExpression ''
            if (lib.hasInfix "100%" lv.config.size) then 9001 else 1000
          '';
          description = "Priority of the logical volume, smaller values are created first";
        };
        size = lib.mkOption {
          type = lib.types.str; # TODO lvm size type
          description = "Size of the logical volume";
        };
        lvm_type = lib.mkOption {
          # TODO: add raid10
          type = lib.types.nullOr (
            lib.types.enum [
              "mirror"
              "raid0"
              "raid1"
              "raid4"
              "raid5"
              "raid6"
              "thin-pool"
              "thinlv"
            ]
          ); # TODO add all lib.types
          default = null; # maybe there is always a default type?
          description = "LVM type";
        };
        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra arguments";
        };
        pool = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Name of pool LV that this LV belongs to";
        };
        content = diskoLib.partitionType {
          parent = config;
          device = "/dev/${config.name}/${lv.config.name}";
        };
      };
    }
  )
)
```

**Default:** `{ }`

---
*Generated with [nix-options-doc](https://github.com/Thunderbottom/nix-options-doc)*
