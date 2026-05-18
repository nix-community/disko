{
  disko.devices = {
    disk = {
      x = {
        type = "disk";
        device = "/dev/sdx";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "64M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
      y = {
        type = "disk";
        device = "/dev/sdy";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "storage";
              };
            };
          };
        };
      };
      z = {
        type = "disk";
        device = "/dev/sdz";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "storage";
              };
            };
          };
        };
      };
      a = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "storage2";
              };
            };
          };
        };
      };
    };
    zpool = {
      storage = {
        type = "zpool";
        mode = "mirror";
        mountpoint = "/storage";

        datasets = {
          dataset = {
            type = "zfs_fs";
            mountpoint = "/storage/dataset";
          };
        };
      };
      storage2 = {
        type = "zpool";
        mountpoint = "/storage2";
        rootFsOptions = {
          canmount = "off";
        };

        datasets = {
          dataset = {
            type = "zfs_fs";
            mountpoint = "/storage2/dataset";
          };
        };
      };
    };
  };
  disko.test = {
    name = "non-root-zfs";
    postDisko = ''
      machine.succeed("mountpoint /mnt/storage")
      machine.succeed("mountpoint /mnt/storage/dataset")

      filesystem = machine.execute("stat --file-system --format=%T /mnt/storage")[1].rstrip()
      print(f"/mnt/storage {filesystem=}")
      assert filesystem == "zfs", "/mnt/storage is not ZFS"

      machine.fail("mountpoint /mnt/storage2")
      machine.succeed("mountpoint /mnt/storage2/dataset")

      filesystem = machine.execute("stat --file-system --format=%T /mnt/storage2")[1].rstrip()
      print(f"/mnt/storage2 {filesystem=}")
      assert filesystem != "zfs", "/mnt/storage should not be ZFS"

      filesystem = machine.execute("stat --file-system --format=%T /mnt/storage2/dataset")[1].rstrip()
      print(f"/mnt/storage2/dataset {filesystem=}")
      assert filesystem == "zfs", "/mnt/storage/dataset is not ZFS"
    '';
    extraChecks = ''
      machine.succeed("mountpoint /storage")
      machine.succeed("mountpoint /storage/dataset")

      filesystem = machine.execute("stat --file-system --format=%T /storage")[1].rstrip()
      print(f"/storage {filesystem=}")
      assert filesystem == "zfs", "/storage is not ZFS"

      machine.fail("mountpoint /storage2")
      machine.succeed("mountpoint /storage2/dataset")

      filesystem = machine.execute("stat --file-system --format=%T /storage2")[1].rstrip()
      print(f"/storage2 {filesystem=}")
      assert filesystem != "zfs", "/storage should not be ZFS"

      filesystem = machine.execute("stat --file-system --format=%T /storage2/dataset")[1].rstrip()
      print(f"/storage2/dataset {filesystem=}")
      assert filesystem == "zfs", "/storage/dataset is not ZFS"
    '';
  };
  networking.hostId = "8425e349";
}
