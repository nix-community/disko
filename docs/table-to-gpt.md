# disko table to gpt migration guide
NixOS on ZFS with latest disko
## Error

WHen deploying NixOS the following trace occurs

```clean=
trace: warning: The legacy table is outdated and should not be used. We recommend using the gpt type instead.
Please note that certain features, such as the test framework, may not function properly with the legacy table type.
If you encounter errors similar to:
"error: The option `disko.devices.disk.disk1.content.partitions."[definition 1-entry 1]".content._config` is read-only, but it's set multiple times,"
this is likely due to the use of the legacy table type.
```

## Before
Configuration in question

```nix=
{ disk ? "/dev/nvme0n1", ... }:
{
  boot.supportedFilesystems = [ "zfs" ];

  disko.devices = {
    disk = {
      nvme = {
        type = "disk";
        device = disk;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "ESP";
              start = "0";
              end = "512MiB";
              fs-type = "fat32";
              bootable = true;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            {
              name = "zfs";
              start = "512MiB";
              end = "100%";
              content = {
                type = "zfs";
                pool = "tank";
              };
            }
          ];
        };
      };
    };
    zpool = {
     ...
    };
  };
}

```
# Migration


The new gpt layout uses partlabels to unify the partiton numbering. for this reason you have to set the partition labels manually if you want to upgrade.
```bash
sgdisk -c 1:disk-nvme-ESP /dev/nvme0n1
sgdisk -c 2:disk-nvme-zfs /dev/nvme0n1
Warning: The kernel is still using the old partition table.
The new table will be used at the next reboot or after you
run partprobe(8) or kpartx(8)
The operation has completed successfully.
```

1 is the partition number (in system `/dev/nvme0n1p`**`1`**)
disk is the parents type (in config: `disko.devices.disk.nvme.type = `**`"disk"`**)
nvme is the parents name ( in config: `disko.devices.disk.`**`nvme`**)
ESP is the name of the partition (in config: `disko.devices.disk.content.partitions.`**`ESP`**)

usually it's okay to fuck this up, since booting an old generation should still be possible as the previous setup used disk numbering instead. When booting the new system you will see that systemd is waiting for the device with the respective partlabel.
# After

```nix=
  disko.devices = {
    disk = {
      nvme = {
        type = "disk";
        device = disk;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512MiB";
              type = "EF00";
              priority = 1; # instead of "start" the priority is used, otherwise the partitions are created alphabetically (ESP before zfs)
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "tank";
              };
            };
          };
        };
      };
    };
    zpool = { ... };
  }
```
