{ disks ? [ "/dev/vdb" ] }: {
  disk = {
    vdb = {
      type = "disk";
      device = builtins.elemAt disks 0;
      content = {
        type = "table";
        format = "gpt";
        partitions = [
          {
            type = "partition";
            name = "ESP";
            start = "1MiB";
            end = "128MiB";
            fs-type = "fat32";
            bootable = true;
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          }
          {
            name = "root";
            type = "partition";
            start = "128MiB";
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

