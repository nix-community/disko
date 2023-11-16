{
  disko.devices = {
    disk = {
      vdb = {
        device = "/dev/disk/by-path/pci-0000:02:00.0-nvme-1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              end = "500M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              name = "root";
              end = "-0";
              content = {
                type = "bcachefs";
                mountpoint = "/";
                extraArgs = [
                  "--compression zstd"
                  "--background_compression zstd"
                  "--block_size=4096" # 4kb block size.
                  "--discard"
                  "--label nroot"
                ];
                mountOptions = [ "noatime" ];
                subvolumes = {
                  # FYI, bcachefs does not support mount of subvolumes externally.
                  # They must all be part of the / hierarchy
                  # and they will be remounted automatically.
                  "/home" = { };
                  "/nix" = { };
                  "/testpath" = { };
                  "/testpath/subdir" = { };
                };
              };
            };
          };
        };
      };
    };
  };
}
