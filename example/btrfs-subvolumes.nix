{
  disko.devices = {
    disk = {
      vdb = {
        type = "disk";
        device = "/dev/disk/by-diskseq/1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "128MiB";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Override existing partition
                subvolumes = {
                  # Subvolume name is different from mountpoint
                  "/rootfs" = {
                    mountpoint = "/";
                  };
                  # Mountpoints inferred from subvolume name
                  "/home" = {
                    mountOptions = [ "compress=zstd" ];
                  };
                  "/nix" = {
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "/test" = { };
                };
              };
            };
          };
        };
      };
    };
  };
}

