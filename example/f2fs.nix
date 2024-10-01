{
  disko.devices = {
    disk = {
      main = {
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
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              name = "root";
              end = "-0";
              content = {
                type = "filesystem";
                format = "f2fs";
                mountpoint = "/";
                extraArgs = [
                  "-O"
                  "extra_attr,inode_checksum,sb_checksum,compression"
                ];
                mountOptions = [
                  "compress_algorithm=zstd:6,compress_chksum,atgc,gc_merge,lazytime,nodiscard"
                ];
              };
            };
          };
        };
      };
    };
  };
}
