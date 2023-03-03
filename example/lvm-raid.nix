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
              end = "100M";
              fs-type = "fat32";
              bootable = true;
              content = {
                type = "mdraid";
                name = "boot";
              };
            }
            {
              type = "partition";
              name = "primary";
              start = "100M";
              end = "100%";
              content = {
                type = "lvm_pv";
                vg = "pool";
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
              end = "100M";
              fs-type = "fat32";
              bootable = true;
              content = {
                type = "mdraid";
                name = "boot";
              };
            }
            {
              type = "partition";
              name = "primary";
              start = "100M";
              end = "100%";
              content = {
                type = "lvm_pv";
                vg = "pool";
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
    };
    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          root = {
            type = "lvm_lv";
            size = "100M";
            lvm_type = "mirror";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [
                "defaults"
              ];
            };
          };
          home = {
            type = "lvm_lv";
            size = "10M";
            lvm_type = "raid0";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/home";
            };
          };
        };
      };
    };
  };
}
