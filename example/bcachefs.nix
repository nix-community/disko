{
  disko.devices = {
    disk = {
      vdb = {
        device = "/dev/vdb";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdb1 = {
              type = "EF00";
              size = "100M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            vdb2 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "root";
                label = "group_a.vdb2";
                extraFormatArgs = [
                  "--discard"
                ];
              };
            };
          };
        };
      };
      vdc = {
        device = "/dev/vdc";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdc1 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "root";
                label = "group_a.vdc1";
                extraFormatArgs = [
                  "--discard"
                ];
              };
            };
          };
        };
      };
      vdd = {
        device = "/dev/vdd";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdd1 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "root";
                label = "group_b.vdd1";
                extraFormatArgs = [
                  "--force"
                ];
              };
            };
          };
        };
      };
    };
    bcachefs_filesystems = {
      root = {
        type = "bcachefs_filesystem";
        mountpoint = "/";
        passwordFile = "/tmp/secret.key";
        extraFormatArgs = [
          "--compression=lz4"
          "--background_compression=lz4"
        ];
        mountOptions = [
          "verbose"
        ];
      };
    };
  };
}