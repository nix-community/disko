{ lib, ... }:
{
  disko.devices.disk = lib.genAttrs [ "a" "b" ] (name: {
    type = "disk";
    device = "/dev/sd${name}";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02"; # for grub MBR
        };
        ESP = {
          size = "500M";
          type = "EF00";
          content = {
            type = "mdraid";
            name = "boot";
          };
        };
        mdadm = {
          size = "100%";
          content = {
            type = "mdraid";
            name = "raid1";
          };
        };
      };
    };
  });
  disko.devices.mdadm = {
    boot = {
      type = "mdadm";
      level = 1;
      metadata = "1.0";
      content = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
        mountOptions = [ "umask=0077" ];
      };
    };
    raid1 = {
      type = "mdadm";
      level = 1;
      content = {
        type = "luks";
        name = "crypted";
        settings.keyFile = "/tmp/secret.key";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/";
        };
      };
    };
  };
}

