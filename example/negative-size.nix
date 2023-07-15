{
  disko.devices = {
    disk = {
      disk0 = {
        device = "/dev/disk/by-id/ata-disk0";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            nix = {
              end = "-10M";
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
