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
}

