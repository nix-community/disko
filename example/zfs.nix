{
  type = "devices";
  content = {
    vdb = {
      type = "zfs";
      pool = "zroot";
    };
    vdc = {
      type = "zfs";
      pool = "zroot";
    };
    zroot = {
      type = "zpool";
      mode = "mirror";
      rootFsOptions = {
        compression = "lz4";
        "com.sun:auto-snapshot" = "false";
      };
      datasets = [
        {
          type = "zfs_filesystem";
          name = "zfs_fs";
          mountpoint = "/zfs_fs";
          options."com.sun:auto-snapshot" = "true";
        }
        {
          type = "zfs_filesystem";
          name = "zfs_legacy_fs";
          options.mountpoint = "legacy";
          mountpoint = "/zfs_legacy_fs";
        }
        {
          type = "zfs_volume";
          name = "zfs_testvolume";
          size = "10M";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/ext4onzfs";
          };
        }
      ];
    };
  };
}

