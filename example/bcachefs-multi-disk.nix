{
  disko.devices = {
    disk = {
      bcachefsmain = {
        device = "/dev/vda";
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
                format = "bcachefs";
                mountpoint = "/";
              };
            };
          };
        };
      };

      bcachefsdisk1 = {
        type = "disk";
        device = "/dev/vdc";
        content = {
          type = "gpt";
          partitions = {
            bcachefs = {
              size = "100%";
              content = {
                type = "bcachefs_member";
                name = "pool1";
                label = "fast";
                discard = true;
                dataAllowed = [ "journal" "btree" ];
                preCreateHook = ''
                  echo "Creating bmember device: $device" >&2
                '';
              };
            };
          };
        };
      };
      bcachefsdisk2 = {
        type = "disk";
        device = "/dev/vdd";
        content = {
          type = "gpt";
          partitions = {
            bcachefs = {
              size = "100%";
              content = {
                type = "bcachefs_member";
                name = "pool1";
                label = "slow";
                durability = 2;
                dataAllowed = [ "user" ];
                preCreateHook = ''
                  echo "Creating bmember device: $device" >&2
                '';
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
      #     type = "bmember";
      #     pool = "pool1";
      #     label = "main";
      #   };
      # };
    };

    bcachefs = {
      pool1 = {
        type = "bcachefs";

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

        mountpoint = "/mnt/pool";
        formatOptions = [ "--compression=zstd" ];
        mountOptions = [ "verbose" "degraded" ];
        preCreateHook = ''
          echo "Creating bcachefs device: $device" >&2
        '';
      };
    };
  };
}
