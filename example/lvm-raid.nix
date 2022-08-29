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
            name = "primary";
            start = "0%";
            end = "100%";
            content = {
              type = "lvm_pv";
              vg = "pool";
            };
          }
        ];
      };
    };
    vdc = {
      type = "disk";
      device = "/dev/vdc";
      content = {
        type = "table";
        format = "gpt";
        partitions = [
          {
            type = "partition";
            name = "primary";
            start = "0%";
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
            options = [
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
}
