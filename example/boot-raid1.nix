{ disks ? [ "/dev/vdb" "/dev/vdc" ], ... }: {
  disko.devices = {
    disk = {
      one = {
        type = "disk";
        device = builtins.elemAt disks 0;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "boot";
              type = "partition";
              start = "0";
              end = "1M";
              part-type = "primary";
              flags = [ "bios_grub" ];
            }
            {
              type = "partition";
              name = "ESP";
              start = "1MiB";
              end = "128MiB";
              fs-type = "fat32";
              bootable = true;
              content = {
                type = "mdraid";
                name = "boot";
              };
            }
            {
              type = "partition";
              name = "mdadm";
              start = "128MiB";
              end = "100%";
              content = {
                type = "mdraid";
                name = "raid1";
              };
            }
          ];
        };
      };
      two = {
        type = "disk";
        device = builtins.elemAt disks 1;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "boot";
              type = "partition";
              start = "0";
              end = "1M";
              part-type = "primary";
              flags = [ "bios_grub" ];
            }
            {
              type = "partition";
              name = "ESP";
              start = "1MiB";
              end = "128MiB";
              fs-type = "fat32";
              bootable = true;
              content = {
                type = "mdraid";
                name = "boot";
              };
            }
            {
              type = "partition";
              name = "mdadm";
              start = "128MiB";
              end = "100%";
              content = {
                type = "mdraid";
                name = "raid1";
              };
            }
          ];
        };
      };
    };
    mdadm = {
      boot = {
        type = "mdadm";
        level = 1;
        metadata = "1.0";
        content = {
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot";
        };
      };
      raid1 = {
        type = "mdadm";
        level = 1;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              type = "partition";
              name = "primary";
              start = "1MiB";
              end = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            }
          ];
        };
      };
    };
  };
}
