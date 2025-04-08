{
  disko.devices = {
    disk = {
      bcachefsmain = {
        device = "/dev/disk/by-path/virtio-pci-0000:00:08.0";
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
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              name = "root";
              end = "-0";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };

      bcachefsdisk1 = {
        type = "disk";
        device = "/dev/disk/by-path/virtio-pci-0000:00:0a.0";
        content = {
          type = "gpt";
          partitions = {
            bcachefs = {
              size = "100%";
              content = {
                type = "bcachefs_member";
                pool = "pool1";
                label = "fast";
                discard = true;
                dataAllowed = [ "journal" "btree" ];
              };
            };
          };
        };
      };
      bcachefsdisk2 = {
        type = "disk";
        device = "/dev/disk/by-path/virtio-pci-0000:00:0b.0";
        content = {
          type = "gpt";
          partitions = {
            bcachefs = {
              size = "100%";
              content = {
                type = "bcachefs_member";
                pool = "pool1";
                label = "slow";
                durability = 2;
                dataAllowed = [ "user" ];
              };
            };
          };
        };
      };
      # use whole disk, ignore partitioning
      # disk3 = {
      #   type = "disk";
      #   device = "/dev/vde";
      #   content = {
      #     type = "bcachefs_member";
      #     pool = "pool1";
      #     label = "main";
      #   };
      # };
    };

    bcachefs = {
      pool1 = {
        type = "bcachefs";

        mountpoint = "/mnt/pool";
        formatOptions = [ "--compression=zstd" ];
        mountOptions = [ "verbose" "degraded" ];
      };
    };
  };
}
