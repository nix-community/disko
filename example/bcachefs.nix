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
                filesystem = "unmounted_subvolumes_in_multi";
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
                filesystem = "unmounted_subvolumes_in_multi";
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
                filesystem = "unmounted_subvolumes_in_multi";
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
            vde1 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "mounted_subvolumes_in_multi";
                label = "group_a.vde1";
                extraFormatArgs = [
                  "--discard"
                ];
              };
            };
          };
        };
      };

      vdf = {
        device = "/dev/vdf";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdf1 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "mounted_subvolumes_in_multi";
                label = "group_a.vdf1";
                extraFormatArgs = [
                  "--discard"
                ];
              };
            };
          };
        };
      };

      vdg = {
        device = "/dev/vdg";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdd1 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "mounted_subvolumes_in_multi";
                label = "group_b.vdg1";
                extraFormatArgs = [
                  "--force"
                ];
              };
            };
          };
        };
      };

      vdh = {
        device = "/dev/vdh";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdd1 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "no_reliance_on_external_subvolume";
                label = "group_a.vdh1";
              };
            };
          };
        };
      };

      vdi = {
        device = "/dev/vdi";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdd1 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "relies_on_external_subvolume";
                label = "group_a.vdi1";
              };
            };
          };
        };
      };
    };

    bcachefs_filesystems = {
      # Example showing unmounted subvolumes in a multi-disk configuration.
      unmounted_subvolumes_in_multi = {
        type = "bcachefs_filesystem";
        passwordFile = "/tmp/secret.key";
        extraFormatArgs = [
          "--compression=lz4"
          "--background_compression=lz4"
        ];
        mountOptions = [
          "verbose"
        ];
        mountpoint = "/";
        subvolumes = {
          "subvolumes/rootfs" = { };
          "subvolumes/home" = { };
          "subvolumes/home/user" = { };
          "subvolumes/nix" = { };
          "subvolumes/test" = { };
        };
      };

      # # Example showing mounted subvolumes in a multi-disk configuration (not yet working).
      # mounted_subvolumes_in_multi = {
      #   type = "bcachefs_filesystem";
      #   passwordFile = "/tmp/secret.key";
      #   extraFormatArgs = [
      #     "--compression=lz4"
      #     "--background_compression=lz4"
      #   ];
      #   mountOptions = [
      #     "verbose"
      #   ];
      #   subvolumes = {
      #     # Subvolume name is different from mountpoint
      #     "foo" = {
      #       mountpoint = "/bar";
      #     };
      #     # Subvolume name is the same as the mountpoint
      #     "home" = {
      #       mountpoint = "/home";
      #     };
      #     # Sub(sub)volume doesn't need a mountpoint as its parent is mounted
      #     "home/user" = {
      #     };
      #     # Parent is not mounted so the mountpoint must be set
      #     "nix" = {
      #       mountpoint = "/nix";
      #     };
      #     # This subvolume will be created but not mounted
      #     "test" = {
      #     };
      #   };
      # };

      # Example showing another bcachefs filesystem.
      no_reliance_on_external_subvolume = {
        type = "bcachefs_filesystem";
        mountpoint = "/sometestdir";
      };

      # # Example showing another bcachefs filesystem that relies on a subvolume
      # # in another filesystem being mounted (not yet working).
      # relies_on_external_subvolume = {
      #   type = "bcachefs_filesystem";
      #   mountpoint = "/home/somedir/vdf1";
      # };
    };
  };
}
