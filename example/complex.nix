{
  disk = {
    disk1 = {
      type = "disk";
      device = "/dev/vdb";
      content = {
        type = "table";
        format = "gpt";
        partitions = [
          {
            type = "partition";
            start = "0";
            end = "1M";
            name = "grub";
            flags = ["bios_grub"];
          }
          {
            type = "partition";
            start = "1M";
            end = "100%";
            name = "luks";
            bootable = true;
            content = {
              type = "luks";
              name = "crypted1";
              keyFile = "/tmp/secret.key";
              extraArgs = [
                "--hash sha512"
                "--iter-time 5000"
              ];
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          }
        ];
      };
    };
    disk2 = {
      type = "disk";
      device = "/dev/vdc";
      content = {
        type = "table";
        format = "gpt";
        partitions = [
          {
            type = "partition";
            start = "0";
            end = "1M";
            name = "grub";
            flags = ["bios_grub"];
          }
          {
            type = "partition";
            start = "1M";
            end = "100%";
            name = "luks";
            bootable = true;
            content = {
              type = "luks";
              name = "crypted2";
              keyFile = "/tmp/secret.key";
              extraArgs = [
                "--hash sha512"
                "--iter-time 5000"
              ];
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          }
        ];
      };
    };
  };
  mdadm = {
    raid1 = {
      type = "mdadm";
      level = 1;
      content = {
        type = "table";
        format = "msdos";
        partitions = [
          {
            type = "partition";
            name = "xfs";
            start = "1MiB";
            end = "100%";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/xfs_mdadm_lvm";
            };
          }
        ];
      };
    };
  };
  lvm_vg = {
    pool = {
      type = "lvm_vg";
      lvs = {
        root = {
          type = "lvm_lv";
          size = "10M";
          lvm_type = "mirror";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/ext4_on_lvm";
            options = [
              "defaults"
            ];
          };
        };
        raid1 = {
          type = "lvm_lv";
          size = "30M";
          lvm_type = "raid0";
          content = {
            type = "mdraid";
            name = "raid1";
          };
        };
        raid2 = {
          type = "lvm_lv";
          size = "30M";
          lvm_type = "raid0";
          content = {
            type = "mdraid";
            name = "raid1";
          };
        };
        zfs1 = {
          type = "lvm_lv";
          size = "128M";
          lvm_type = "raid0";
          content = {
            type = "zfs";
            pool = "zroot";
          };
        };
        zfs2 = {
          type = "lvm_lv";
          size = "128M";
          lvm_type = "raid0";
          content = {
            type = "zfs";
            pool = "zroot";
          };
        };
      };
    };
  };
  zpool = {
    zroot = {
      type = "zpool";
      mode = "mirror";
      rootFsOptions = {
        compression = "lz4";
        "com.sun:auto-snapshot" = "false";
      };
      mountpoint = "/";

      datasets = {
        zfs_fs = {
          zfs_type = "filesystem";
          mountpoint = "/zfs_fs";
          options."com.sun:auto-snapshot" = "true";
        };
        zfs_unmounted_fs = {
          zfs_type = "filesystem";
          options.mountpoint = "none";
        };
        zfs_legacy_fs = {
          zfs_type = "filesystem";
          options.mountpoint = "legacy";
          mountpoint = "/zfs_legacy_fs";
        };
        zfs_testvolume = {
          zfs_type = "volume";
          size = "10M";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/ext4onzfs";
          };
        };
      };
    };
  };
}
