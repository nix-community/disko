{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/vdb";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "500M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                settings.allowDiscards = true;
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
  };

  # If we don't set passwordFile above, we will be interactively prompted by the
  # disko script to set the LUKS password. However, as passwordFile is necessary
  # for installTest we set it here.
  disko.tests.extraDiskoConfig = {
    devices.disk.vdb.content.partitions.luks.content.passwordFile = "/tmp/secret.key";
  };
}
