let
  headerDevice = "/dev/disk/by-partlabel/disk-main-luks-header";
in
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/vdb";
        content = {
          type = "gpt";
          partitions = {
            luks-header = {
              size = "32M";
              type = "8300";
            };
            crypt = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                settings = {
                  header = headerDevice;
                  keyFile = "/tmp/secret.key";
                };
                extraFormatArgs = [ "--header=${headerDevice}" ];
                extraOpenArgs = [ "--header=${headerDevice}" ];
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
}
