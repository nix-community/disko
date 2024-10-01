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
                mountOptions = [ "umask=0077" ];
              };
            };
            primary = {
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "mainpool";
              };
            };
          };
        };
      };
    };
    lvm_vg = {
      mainpool = {
        type = "lvm_vg";
        lvs = {
          thinpool = {
            size = "100M";
            lvm_type = "thin-pool";
          };
          root = {
            size = "10M";
            lvm_type = "thinlv";
            pool = "thinpool";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [
                "defaults"
              ];
            };
          };
          home = {
            size = "10M";
            lvm_type = "thinlv";
            pool = "thinpool";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/home";
            };
          };
          raw = {
            size = "10M";
          };
        };
      };
    };
  };
}
