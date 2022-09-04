{
  disk = {
    vdb = {
      type = "disk";
      device = "/dev/vdb";
      content = {
        type = "zfs";
        pool = "zroot";
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
      mode = "mirror";
      rootFsOptions = {
        compression = "lz4";
        "com.sun:auto-snapshot" = "false";
      };
      mountpoint = "/";

      datasets = {
        zfs_fs = {
          zfs_type = "filesystem";
          mountpoint = "/zfs_fs";
          options."com.sun:auto-snapshot" = "true";
        };
        zfs_unmounted_fs = {
          zfs_type = "filesystem";
          options.mountpoint = "none";
        };
        zfs_legacy_fs = {
          zfs_type = "filesystem";
          options.mountpoint = "legacy";
          mountpoint = "/zfs_legacy_fs";
        };
        zfs_testvolume = {
          zfs_type = "volume";
          size = "10M";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/ext4onzfs";
          };
        };
      };
    };
  };
}

