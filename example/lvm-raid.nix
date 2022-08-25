{
  type = "devices";
  content = {
    vdb = {
      type = "table";
      format = "gpt";
      partitions = [
        {
          type = "partition";
          part-type = "primary";
          start = "0%";
          end = "100%";
          content = {
            type = "lvm_pv";
            vg = "pool";
          };
        }
      ];
    };
    vdc = {
      type = "table";
      format = "gpt";
      partitions = [
        {
          type = "partition";
          part-type = "primary";
          start = "0%";
          end = "100%";
          content = {
            type = "lvm_pv";
            vg = "pool";
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
