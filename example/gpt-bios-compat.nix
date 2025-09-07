# Example to create a bios compatible gpt partition
{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/vdb";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # for grub MBR
              attributes = [ 0 ]; # partition attribute
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
