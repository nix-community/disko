{
  type = "devices";
  content = {
    vdb = {
      type = "table";
      format = "gpt";
      partitions = [
        {
          type = "partition";
          part-type = "ESP";
          start = "1MiB";
          end = "100MiB";
          fs-type = "FAT32";
          bootable = true;
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            options = [
              "defaults"
            ];
          };
        }
        {
          type = "partition";
          part-type = "primary";
          start = "100MiB";
          end = "100%";
          content = {
            type = "luks";
            algo = "aes-xts...";
            name = "crypted";
            keyfile = "/tmp/secret.key";
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
    pool = {
      type = "lvm_vg";
        lvs = {
          root = {
            type = "lvm_lv";
            size = "100M";
            mountpoint = "/";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              options = [
                "defaults"
              ];
            };
          };
          home = {
            type = "lvm_lv";
            size = "10M";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/home";
            };
          };
          raw = {
            type = "lvm_lv";
            size = "10M";
            content = {
              type = "noop";
            };
          };
        };
    };
  };
}
