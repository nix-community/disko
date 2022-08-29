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
            name = "root";
            type = "partition";
            start = "0%";
            end = "100%";
            content = {
              type = "btrfs";
              mountpoint = "/";
              subvolumes = [
                "/home"
                "/test"
              ];
            };
          }
        ];
      };
    };
  };
}

