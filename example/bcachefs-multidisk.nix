{
  disko.devices = {
    disk = {
      x = {
        type = "disk";
        device = "/dev/sdx";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "64M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            bcachefs = {
              size = "100%";
              content = {
                type = "bcachefs";
                pool = "broot";
              };
            };
          };
        };
      };
      y = {
        type = "disk";
        device = "/dev/sdy";
        content = {
          type = "gpt";
          partitions = {
            bcachefs = {
              size = "100%";
              content = {
                type = "bcachefs";
                pool = "broot";
              };
            };
          };
        };
      };
    };
    bcachefspool = {
      broot = {
        type = "bcachefspool";
        mountpoint = "/";
      };
    };
  };
}

