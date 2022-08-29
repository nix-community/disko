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
            start = "0%";
            end = "100%";
            name = "primary";
            bootable = true;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          }
        ];
      };
    };
    vdc = {
      type = "disk";
      device = "/dev/vdc";
      content = {
        type = "zfs";
        pool = "zroot";
      };
    };
  };
  zpool = {
    zroot = {
      type = "zpool";
      datasets = {
        zfs_fs = {
          zfs_type = "filesystem";
          mountpoint = "/zfs_fs";
          options."com.sun:auto-snapshot" = "true";
        };
      };
    };
  };
}

