{
  disko.devices = {
    disk = {
      x = {
        type = "disk";
        device = "/dev/sdx";
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
      y = {
        type = "disk";
        device = "/dev/sdy";
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
    };
    zpool = {
      zroot = {
        type = "zpool";
        mode = "mirror";
        # Workaround: cannot import 'zroot': I/O error in disko tests
        options.cachefile = "none";
        rootFsOptions = {
          compression = "zstd";
          "com.sun:auto-snapshot" = "false";
        };
        mountpoint = "/";
        postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zroot@blank$' || zfs snapshot zroot@blank";

        datasets = {
          zfs_fs = {
            type = "zfs_fs";
            mountpoint = "/zfs_fs";
            options."com.sun:auto-snapshot" = "true";
          };
          zfs_unmounted_fs = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          zfs_legacy_fs = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/zfs_legacy_fs";
          };
          zfs_volume = {
            type = "zfs_volume";
            size = "10M";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/ext4onzfs";
            };
          };
          zfs_volume_no_content = {
            type = "zfs_volume";
            size = "10M";
          };
          zfs_encryptedvolume = {
            type = "zfs_volume";
            size = "10M";
            options = {
              encryption = "aes-256-gcm";
              keyformat = "passphrase";
              keylocation = "file:///tmp/secret.key";
            };
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/ext4onzfsencrypted";
            };
          };
          encrypted = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              encryption = "aes-256-gcm";
              keyformat = "passphrase";
              keylocation = "file:///tmp/secret.key";
            };
            # use this to read the key during boot
            # postCreateHook = ''
            #   zfs set keylocation="prompt" "zroot/$name";
            # '';
          };
          "encrypted/test" = {
            type = "zfs_fs";
            mountpoint = "/zfs_crypted";
          };
        };
      };
    };
  };
}
