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
  disko.test = {
    name = "zfs";
    nodes.machine.fileSystems."/zfs_legacy_fs".options = [ "nofail" ]; # TODO find out why we need this!
    extraChecks = ''
      machine.succeed("test -b /dev/zvol/zroot/zfs_volume");
      machine.succeed("test -b /dev/zvol/zroot/zfs_encryptedvolume");

      def assert_property(ds, property, expected_value):
          out = machine.succeed(f"zfs get -H {property} {ds} -o value").rstrip()
          assert (
              out == expected_value
          ), f"Expected {property}={expected_value} on {ds}, got: {out}"

      assert_property("zroot", "compression", "zstd")
      assert_property("zroot/zfs_fs", "compression", "zstd")
      assert_property("zroot", "com.sun:auto-snapshot", "false")
      assert_property("zroot/zfs_fs", "com.sun:auto-snapshot", "true")
      assert_property("zroot/zfs_volume", "volsize", "10M")
      assert_property("zroot/zfs_encryptedvolume", "volsize", "10M")
      assert_property("zroot/zfs_unmounted_fs", "mountpoint", "none")

      machine.succeed("zfs get name zroot@blank")

      machine.succeed("mountpoint /zfs_fs");
      machine.succeed("mountpoint /zfs_legacy_fs");
      machine.succeed("mountpoint /ext4onzfs");
      machine.succeed("mountpoint /ext4onzfsencrypted");
      machine.succeed("mountpoint /zfs_crypted");
      machine.succeed("zfs get keystatus zroot/encrypted");
      machine.succeed("zfs get keystatus zroot/encrypted/test");
    '';
  };
  networking.hostId = "8425e349";
}
