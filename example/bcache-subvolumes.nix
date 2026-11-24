{
  disko.devices = {
    disk = {
      fast = {
        type = "disk";
        device = "/dev/cache-disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "500M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "2G";
              content = {
                type = "btrfs";
                mountpoint = "/";
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

      large = {
        type = "disk";
        device = "/dev/backing-disk";
        content = {
          type = "gpt";
          partitions = {
            storage = {
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
          type = "btrfs";
          subvolumes = {
            "@data" = {
              mountpoint = "/data";
            };
            "@nix-store" = {
              mountpoint = "/nix/store";
            };
          };
        };
      };
    };
  };
}
