{
  disko.devices = {
    disk = {
      vdb = {
        device = "/dev/disk/by-id/some-disk-id";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "100M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            "name with spaces" = {
              size = "100M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/name with spaces";
              };
            };
            "name^with\\some@special#chars" = {
              size = "100M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/name^with\\some@special#chars";
              };
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
