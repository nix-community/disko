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
                passwordFile = "/tmp/secret.key";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
