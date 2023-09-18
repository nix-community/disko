# 2023-07-09 121df48

Changes:

- BTRFS subvolumes are mounted if and only their `mountpoint` is set.

Especially, if you have specific mount options for a subvolume (through
`mountOptions`), make sure to set `mountpoint` otherwise the subvolume will not
be mounted.

This change allows more flexibility when using BTRFS, giving access to its
volume management functionality.

It allows layouts as the following:

```nix
content = {
  type = "btrfs";
  # BTRFS partition is not mounted as it doesn't set a mountpoint explicitly
  subvolumes = {
    # This subvolume will not be mounted
    "SYSTEM" = { };
    # mounted as "/"
    "SYSTEM/rootfs" = {
      mountpoint = "/";
    };
    # mounted as "/nix"
    "SYSTEM/nix" = {
      mountOptions = [ "compress=zstd" "noatime" ];
      mountpoint = "/nix";
    };
    # This subvolume will not be mounted
    "DATA" = { };
    # mounted as "/home"
    "DATA/home" = {
      mountOptions = [ "compress=zstd" ];
      mountpoint = "/home";
    };
    # mounted as "/var/www"
    "DATA/www" = {
      mountpoint = "/var/www";
    };
  };
};
```

corresponding to the following BTRFS layout:

```
BTRFS partition # not mounted
 |
 |-SYSTEM       # not mounted
 |  |-rootfs    # mounted as "/"
 |  |-nix       # mounted as "/nix"
 |
 |-DATA         # not mounted
    |-home      # mounted as "/home"
    |-www       # mounted as "/var/www"
```

# 2023-04-07 7d70009

Changes:

- ZFS datasets have been split into two types: `zfs_fs` and `zfs_volume`.
- The `zfs_type` attribute has been removed.
- The size attribute is now only available for `zfs_volume`.

Updated example/zfs.nix file:

```nix
{
datasets = {
  zfs_fs = {
    type = "zfs_fs";
    mountpoint = "/zfs_fs";
    options."com.sun:auto-snapshot" = "true";
  };
  zfs_unmounted_fs = {
    type = "zfs_fs";
    options.mountpoint = "none";
  };
  zfs_legacy_fs = {
    type = "zfs_fs";
    options.mountpoint = "legacy";
    mountpoint = "/zfs_legacy_fs";
  };
  zfs_testvolume = {
    type = "zfs_volume";
    size = "10M";
    content = {
      type = "filesystem";
      # ...
}
```

Note: The `zfs_type` attribute has been replaced with a type attribute for each
dataset, and the `size` attribute is only available for `zfs_volume`. These
changes have been reflected in the `example/zfs.nix` file.

# 2023-04-07 654ecb3

The `lvm_lv` type is always part of an `lvm_vg` and it is no longer necessary to
specify the type.

This means that if you were using the `lvm_lv` type in your code, you should
remove it. For example, if you were defining an `lvm_lv` type like this:

```nix
{
  type = "lvm_lv";
  size = "10G";
  # ...
}
```

You should now define it like this:

```nix
{
  size = "10G";
  # ...
}
```

Note that the `type` field is no longer necessary and should be removed from
your code.

# 2023-04-07 d6f062e

Partition types are now always part of a table and cannot be specified
individually anymore. This change makes the library more consistent and easier
to use.

Example of how to change code:

Before:

```nix
{
  type = "partition";
  name = "ESP";
  start = "1MiB";
  end = "100MiB";
  part-type = "primary";
}
```

After:

```nix
{
  name = "ESP";
  start = "1MiB";
  end = "100MiB";
  part-type = "primary";
}
```

Note that the `type` field is no longer necessary and should be removed from
your code.

# 2023-03-22 2624af6

disk config now needs to be inside a disko.devices attrset always

# 2023-03-22 0577409

the extraArgs option in the luks type was renamed to extraFormatArgs

# 2023-02-14 6d630b8

btrfs, `btrfs_subvol` filesystem and `lvm_lv` extraArgs are now lists
