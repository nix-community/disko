{
  disko.devices = {
    disk = {
      boot = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "1024M";
              name = "boot";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "umask=0022"
                  "iocharset=utf8"
                  "rw"
                ];
              };
            };

            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };

      data1 = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zraid";
              };
            };
          };
        };
      };

      data2 = {
        type = "disk";
        device = "/dev/sdb";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zraid";
              };
            };
          };
        };
      };

      data3 = {
        type = "disk";
        device = "/dev/sdc";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zraid";
              };
            };
          };
        };
      };
    };

    zpool = {
      zroot = {
        type = "zpool";
        mode = {
          rootFsOptions = {
            compression = "zstd";
            mountpoint = "none";
          };

          datasets = {
            "root" = {
              type = "zfs_fs";
              mountpoint = "/";
            };

            "root/nix" = {
              type = "zfs_fs";
              mountpoint = "/nix";

              options = {
                mountpoint = "/nix";
              };
            };

            "root/home" = {
              type = "zfs_fs";
              mountpoint = "/home";

              options = {
                mountpoint = "/home";
              };
            };
          };
        };
      };

      zraid = {
        type = "zpool";
        mode = {
          rootFsOptions = {
            compression = "zstd";
            mountpoint = "none";
          };

          topology = {
            type = "topology";
            mountpoint = "/zraid";

            vdev = [
              {
                mode = "raidz1";
                members = [
                  "data1"
                  "data2"
                  "data3"
                ];
              }
            ];
          };
        };
      };
    };
  };
}
