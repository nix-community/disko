{
  disko.devices = {
    disk = {
      vdb = {
        device = "/dev/vdb";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdb1 = {
              type = "EF00";
              size = "100M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            vdb2 = {
              size = "100%";
              content = {
                type = "bcachefs";
                # This refers to a filesystem in the `bcachefs_filesystems` attrset below.
                filesystem = "mounted_subvolumes_in_multi";
                label = "group_a.vdb2";
                extraFormatArgs = [
                  "--discard"
                ];
              };
            };
          };
        };
      };

      vdc = {
        device = "/dev/vdc";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdc1 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "mounted_subvolumes_in_multi";
                label = "group_a.vdc1";
                extraFormatArgs = [
                  "--discard"
                ];
              };
            };
          };
        };
      };

      vdd = {
        device = "/dev/vdd";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdd1 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "mounted_subvolumes_in_multi";
                label = "group_b.vdd1";
                extraFormatArgs = [
                  "--force"
                ];
              };
            };
          };
        };
      };

      vde = {
        device = "/dev/vde";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdd1 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "relies_on_external_subvolume";
                label = "group_a.vde1";
              };
            };
          };
        };
      };
    };

    bcachefs_filesystems = {
      # Example showing mounted subvolumes in a multi-disk configuration.
      mounted_subvolumes_in_multi = {
        type = "bcachefs_filesystem";
        passwordFile = "/tmp/secret.key";
        extraFormatArgs = [
          "--compression=lz4"
          "--background_compression=lz4"
        ];
        subvolumes = {
          # Subvolume name is different from mountpoint.
          "subvolumes/root" = {
            mountpoint = "/";
            mountOptions = [
              "verbose"
            ];
          };
          # Subvolume name is the same as the mountpoint.
          "subvolumes/home" = {
            mountpoint = "/home";
          };
          # Nested subvolume doesn't need a mountpoint as its parent is mounted.
          "subvolumes/home/user" = {
          };
          # Parent is not mounted so the mountpoint must be set.
          "subvolumes/nix" = {
            mountpoint = "/nix";
          };
          # This subvolume will be created but not mounted.
          "subvolumes/test" = {
          };
        };
      };

      # Example showing a bcachefs filesystem without subvolumes
      # and which relies on a subvolume in another filesystem being mounted.
      relies_on_external_subvolume = {
        type = "bcachefs_filesystem";
        mountpoint = "/home/Documents";
        extraFormatArgs = [
          "--compression=lz4"
          "--background_compression=lz4"
        ];
        mountOptions = [
          "verbose"
        ];
      };
    };
  };
}
