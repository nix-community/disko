{
  disk = {
    vdb = {
      type = "disk";
      device = "/dev/vdb";
      content = {
        type = "table";
        format = "gpt";
        partitions = [
          {
            type = "partition";
            name = "ESP";
            # fs-type = "FAT32";
            start = "1MiB";
            end = "100MiB";
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
            name = "luks";
            start = "100MiB";
            end = "100%";
            content = {
              type = "luks";
              name = "crypted";
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
  lvm_vg = {
    pool = {
      type = "lvm_vg";
      lvs = {
        root = {
          type = "lvm_lv";
          size = "100M";
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
        };
      };
    };
  };
}
