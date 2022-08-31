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
            subvolumes = {
              # Subvolume name is different from mountpoint
              rootfs = {
                mountpoint = "/";
              };
              # Mountpoint s inferred from subvolume name
              "/home" = {
                mountOptions = ["compress=zstd"];
              };
              "/nix" = {
                mountOptions = ["compress=zstd" "noatime"];
              };
              "/test" = {};
            };
          };
        }
      ];
    };
  };
}
