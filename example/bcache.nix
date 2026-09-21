{
  disko.devices = {
    disk = {
      cache-disk = {
        type = "disk";
        device = "/dev/my-cache-disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # for grub MBR
            };
            boot-fs = {
              size = "500M";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/boot";
              };
            };
            cache = {
              size = "100%";
              content = {
                type = "bcache_cache";
                set = "main";
              };
            };
          };
        };
      };
      backing-disk = {
        type = "disk";
        device = "/dev/my-backing-disk";
        content = {
          type = "gpt";
          partitions = {
            backing = {
              size = "100%";
              content = {
                type = "bcache_backing";
                set = "main";
              };
            };
          };
        };
      };
    };
    bcache = {
      main = {
        type = "bcache";
        device = "/dev/bcache0";
        cacheMode = "writeback";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/";
        };
      };
    };
  };
}
