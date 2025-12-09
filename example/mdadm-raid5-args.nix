{
  disko.devices = {
    disk = {
      disk1 = {
        type = "disk";
        device = "/dev/my-disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # for grub MBR
            };
            mdadm = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "raid5";
              };
            };
          };
        };
      };
      disk2 = {
        type = "disk";
        device = "/dev/my-disk2";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # for grub MBR
            };
            mdadm = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "raid5";
              };
            };
          };
        };
      };
    };
    mdadm = {
      raid5 = {
        type = "mdadm";
        level = 5;
        content = {
          type = "gpt";
          partitions = {
            primary = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
        extraArgs = [ "--assume-clean" ];
      };
    };
  };
}
