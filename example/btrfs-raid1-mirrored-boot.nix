{
  disko.devices.disk = {
    one = {
      type = "disk";
      device = "/dev/vda";

      content = {
        type = "gpt";

        partitions = {
          boot = {
            size = "1M";
            type = "EF02";
          };

          esp = {
            size = "1G";
            type = "EF00";

            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot0";
              mountOptions = [ "umask=0077" ];
            };
          };

          root = {
            size = "100%";

            content = {
              type = "btrfs";
            };
          };
        };
      };
    };

    two = {
      type = "disk";
      device = "/dev/vdb";

      content = {
        type = "gpt";

        partitions = {
          boot = {
            size = "1M";
            type = "EF02";
          };

          esp = {
            size = "1G";
            type = "EF00";

            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot1";
              mountOptions = [ "umask=0077" ];
            };
          };

          root = {
            size = "100%";

            content = {
              type = "btrfs";
              mountpoint = "/";
              extraArgs = [
                "-f"
                "-d raid1"
                "/dev/disk/by-partlabel/disk-one-root"
              ];
            };
          };
        };
      };
    };
  };
}
