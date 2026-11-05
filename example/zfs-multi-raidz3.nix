{
  disko.devices = {
    disk = {
      boot = {
        type = "disk";
        device = "/dev/vda";
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
                mountOptions = [ "umask=0077" ];
              };
            };
          };
        };
      };
    }
    // (builtins.listToAttrs (
      builtins.genList (i: {
        name = "disk${toString i}";
        value = {
          type = "disk";
          device = "/dev/sd${
            if i < 26 then
              builtins.substring i 1 "abcdefghijklmnopqrstuvwxyz"
            else
              "a${builtins.substring (i - 26) 1 "abcdefghijklmnopqrstuvwxyz"}"
          }";
          content = {
            type = "gpt";
            partitions = {
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
      }) 36
    ));
    zpool = {
      zroot = {
        type = "zpool";
        mode = {
          topology = {
            type = "topology";
            vdev = [
              # First raidz3 group: disks 0-10 (11 disks)
              {
                mode = "raidz3";
                members = builtins.genList (i: "disk${toString i}") 11;
              }
              # Second raidz3 group: disks 11-21 (11 disks)
              {
                mode = "raidz3";
                members = builtins.genList (i: "disk${toString (i + 11)}") 11;
              }
              # Third raidz3 group: disks 22-32 (11 disks)
              {
                mode = "raidz3";
                members = builtins.genList (i: "disk${toString (i + 22)}") 11;
              }
            ];
            # 3 hot spares: disks 33-35
            spare = builtins.genList (i: "disk${toString (i + 33)}") 3;
          };
        };
        rootFsOptions = {
          compression = "zstd";
          "com.sun:auto-snapshot" = "false";
        };
        mountpoint = "/";
        datasets = {
          zfs_fs = {
            type = "zfs_fs";
            mountpoint = "/zfs_fs";
            options."com.sun:auto-snapshot" = "true";
          };
        };
      };
    };
  };
}
