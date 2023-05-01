# meant for NAS setups with raidzX approach.
{ root_disk ? "/dev/vdb"
, raid_disks ? {
    # better use /dev/disk/by-id/
    "vendor_id1" = "/dev/vdc";
    "vendor_id2" = "/dev/vdd";
    "vendor_id3" = "/dev/vde";
  }
, ...
}:
{
  disko.devices = {
    disk = {
      root = {
        type = "disk";
        device = root_disk;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "ESP";
              start = "0";
              end = "500MiB";
              bootable = true;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "defaults"
                ];
              };
            }
            {
              name = "zfs";
              start = "500MiB";
              end = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            }
          ];
        };
      };
    } // builtins.mapAttrs
      (_: device_path: {
        type = "disk";
        device = device_path;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "zfs";
              start = "0";
              end = "100%";
              content = {
                type = "zfs";
                pool = "zraid";
              };
            }
          ];
        };
      }
      )
      raid_disks;

    zpool = {

      zroot = {
        type = "zpool";
        rootFsOptions = {
          mountpoint = "none";
          canmount = "off";
        };
        datasets = {
          "root" = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              mountpoint = "legacy";
              compression = "lz4";
            };
          };
        };
      };

      # `zpool import -f zraid` once on the first boot and reboot as well everytime you change networking.hostname or networking.hostId
      zraid = {
        type = "zpool";
        mode = "raidz1";
        rootFsOptions = {
          mountpoint = "none";
          canmount = "off";
        };
        datasets = {
          "media" = {
            type = "zfs_fs";
            mountpoint = "/media";
            options = {
              mountpoint = "legacy";
              compression = "lz4";
            };
          };
          "nextcloud" = {
            type = "zfs_fs";
            mountpoint = "/nextcloud";
            options = {
              mountpoint = "legacy";
              compression = "lz4";
              "com.sun:auto-snapshot" = "false";
              "com.sun:auto-snapshot:daily" = "true,keep=32";
            };
          };
        };
      };

    };
  };
}

