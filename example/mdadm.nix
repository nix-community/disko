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
            name = "mdadm";
            start = "1MiB";
            end = "100%";
            content = {
              type = "mdraid";
              name = "raid1";
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
            name = "mdadm";
            start = "1MiB";
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
              mountpoint = "/raid";
            };
          }
        ];
      };
    };
  };
}
