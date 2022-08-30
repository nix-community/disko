{
  type = "devices";
  content = {
    vdb = {
      type = "table";
      format = "gpt";
      partitions = [
        {
          type = "partition";
          # leave space for the grub aka BIOS boot
          start = "0%";
          end = "100%";
          part-type = "primary";
          bootable = true;
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        }
      ];
    };
    vdc = {
      type = "zfs";
      pool = "zroot";
    };
    zroot = {
      type = "zpool";
      mountpoint = "/";

      datasets = [
        {
          type = "zfs_filesystem";
          name = "zfs_fs";
          mountpoint = "/zfs_fs";
          options."com.sun:auto-snapshot" = "true";
        }
      ];
    };
  };
}

