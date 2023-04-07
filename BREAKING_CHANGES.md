2023-04-07 7d70009

zfs_datasets are now split into zfs_fs and zfs_volume. zfs_type got removed. size is only available for zfs_volume

2023-04-07 654ecb3

lvm_lv types are always part of a lvm_vg and it is no longer possible (and neccessary) to specify the type

2023-04-07 d6f062e

parition types are always part of a table and it is no longer possible (and neccessary) to specify the type

2023-03-22 2624af6

disk config now needs to be inside a disko.devices attrset always

2023-03-22 0577409

the extraArgs option in the luks type was renamed to extraFormatArgs

2023-02-14 6d630b8

btrfs, btrfs_subvol filesystem and lvm_lv extraArgs are now lists
