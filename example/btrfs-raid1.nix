{
  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "1024M";
              name = "boot";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "umask=0022"
                  "iocharset=utf8"
                  "rw"
                ];
              };
            };
            empty = {
              # in order for btrfs raid to work we need to do this
              size = "100%";
            };
          };
        };
      };
      nvme1 = {
        type = "disk";
        device = "/dev/nvme1n1";
        content = {
          type = "gpt";
          partitions = {
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  "-m raid1"
                  "-d single"
                  "/dev/nvme0n1p2" # needs to be partition 2 of 1st disk and needs to be 2nd disk
                ];
                mountpoint = "/";
                mountOptions = [
                  "rw"
                  "ssd_spread"
                  "max_inline=256"
                  "commit=150"
                  "compress=zstd"
                  "noatime"
                  "discard=async"
                ];
              };
            };
          };
        };
      };
    };
  };
}
