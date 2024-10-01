# Migrating to the new GPT layout

## Situation

When evaluating your NixOS system closure the following trace appears:

```
trace: warning: The legacy table is outdated and should not be used. We recommend using the gpt type instead.
Please note that certain features, such as the test framework, may not function properly with the legacy table type.
If you encounter errors similar to:
"error: The option `disko.devices.disk.disk1.content.partitions."[definition 1-entry 1]".content._config` is read-only, but it's set multiple times,"
this is likely due to the use of the legacy table type.
```

The solution is to migrate to the new `gpt` layout type.

## Precondition

Disko was set up with

- `type = "table"` and
- `format = "gpt"`,

for example like this:

```nix
{
  disko.devices.disk.example = {
    type = "disk";
    device = "/dev/nvme0n1";
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
        }
        {
          name = "root";
          start = "512MiB";
          end = "100%";
          content.format = "ext4";
        }
      ];
    };
  };
}
```

## Remediation

The new GPT layout (`type = "gpt"`) uses partlabels to realize the partiton
numbering. For this reason you have to manually set up partition labels, if you
want to resolve this issue.

### Create GPT partition labels

For each partition involved, create the partition label from these components:

- The partition number (e.g. /dev/nvme0n**1**, or /dev/sda**1**)
- The parent type in your disko config (value of
  `disko.device.disk.example.type = "disk";`)
- The parent name in your disko config (attribute name of
  `disko.devices.disk.example`, so `example` in this example)
- The partition name in your disko config (attribute name of
  `disko.devices.disk.content.partitions.*.name`)

```bash
# sgdisk -c 1:disk-example-ESP /dev/nvme0n1
# sgdisk -c 2:disk-example-zfs /dev/nvme0n1
Warning: The kernel is still using the old partition table.
The new table will be used at the next reboot or after you
run partprobe(8) or kpartx(8)
The operation has completed successfully.
```

### Update disko configuration

Make the following changes to your disko configuration:

1. Set `disko.devices.disk.example.content.type = "gpt"`
1. Remove `disko.devices.disk.example.format`
1. Convert `disko.devices.disk.example.partitions` to an attribute set and
   promote the `name` field to the key for its partition
1. Add a `priority` field to each partition, to reflect the intended partition
   number

Then rebuild your system and reboot.

### Recovering from mistake

If you made a mistake here, your system will be waiting for devices to appear,
and then run into timeouts. You can easily recover from this, since rebooting
into an old generation will still use the legacy way of numbering of partitions.

## Result

The fixed disko configuration would look like this:

```nix
{
  disko.devices.disk.example = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512MiB";
          type = "EF00";
          priority = 1;
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          priority = 2;
          content.format = "ext4";
        };
      };
    };
  };
}
```
