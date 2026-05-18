{
  disko.devices = {
    disk = {
      data1 = {
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
      data2 = {
        type = "disk";
        device = "/dev/vdb";
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
      data3 = {
        type = "disk";
        device = "/dev/vdc";
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
      spare = {
        type = "disk";
        device = "/dev/vdd";
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
      log1 = {
        type = "disk";
        device = "/dev/vde";
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
      log2 = {
        type = "disk";
        device = "/dev/vdf";
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
      log3 = {
        type = "disk";
        device = "/dev/vdg";
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
      dedup1 = {
        type = "disk";
        device = "/dev/vdh";
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
      dedup2 = {
        type = "disk";
        device = "/dev/vdi";
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
      dedup3 = {
        type = "disk";
        device = "/dev/vdj";
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
      special1 = {
        type = "disk";
        device = "/dev/vdk";
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
      special2 = {
        type = "disk";
        device = "/dev/vdl";
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
      special3 = {
        type = "disk";
        device = "/dev/vdm";
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
      cache = {
        type = "disk";
        device = "/dev/vdn";
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
        mode = {
          topology = {
            type = "topology";
            vdev = [
              {
                # This syntax expects a disk called 'data1' with a gpt partition called 'zfs'.
                members = [ "data1" ];
                # It's also possible to use the full path of the device or partition
                # members = [ "/dev/disk/by-id/wwn-0x5000c500af8b2a14" ];
              }
              {
                mode = "mirror";
                members = [
                  "data2"
                  "data3"
                ];
              }
            ];
            spare = [ "spare" ];
            log = [
              {
                mode = "mirror";
                members = [
                  "log1"
                  "log2"
                ];
              }
              {
                members = [ "log3" ];
              }
            ];
            dedup = [
              {
                mode = "mirror";
                members = [
                  "dedup1"
                  "dedup2"
                ];
              }
              {
                members = [ "dedup3" ];
              }
            ];
            special = [
              {
                mode = "mirror";
                members = [
                  "special1"
                  "special2"
                ];
              }
              {
                members = [ "special3" ];
              }
            ];
            cache = [ "cache" ];
          };
        };

        rootFsOptions = {
          compression = "zstd";
          "com.sun:auto-snapshot" = "false";
        };
        mountpoint = "/";
        datasets = {
          # See examples/zfs.nix for more comprehensive usage.
          zfs_fs = {
            type = "zfs_fs";
            mountpoint = "/zfs_fs";
            options."com.sun:auto-snapshot" = "true";
          };
        };
      };
    };
  };
  disko.test = {
    name = "zfs-with-vdevs";
    nodes.machine = {
      # It looks like the 60s of NixOS is sometimes not enough for our virtio-based zpool.
      # This fixes the flakeiness of the test.
      boot.initrd.postResumeCommands = ''
        for i in $(seq 1 120); do
          if zpool list | grep -q zroot || zpool import -N zroot; then
            break
          fi
        done
      '';
    };
    extraChecks = ''
      def assert_property(ds, property, expected_value):
          out = machine.succeed(f"zfs get -H {property} {ds} -o value").rstrip()
          assert (
              out == expected_value
          ), f"Expected {property}={expected_value} on {ds}, got: {out}"

      # These fields are 0 if l2arc is disabled
      assert (
          machine.succeed(
              "cat /proc/spl/kstat/zfs/arcstats"
              " | grep '^l2_' | tr -s ' '"
              " | cut -s -d ' ' -f3 | uniq"
          ).strip() != "0"
      ), "Excepted cache to be utilized."

      assert_property("zroot", "compression", "zstd")
      assert_property("zroot/zfs_fs", "com.sun:auto-snapshot", "true")
      assert_property("zroot/zfs_fs", "compression", "zstd")
      machine.succeed("mountpoint /zfs_fs");

      group = ""
      vdev = ""
      actual = []
      for line in machine.succeed("zpool status -P zroot").split("\n"):
          first_word = line.strip().split(" ", 1)[0]
          if line.startswith("\t  ") and first_word.startswith("/"):
              actual.append(f"{group}{vdev}{first_word}")
          elif line.startswith("\t  "):
              vdev = f"{first_word.split('-', 1)[0]} "
          elif line.startswith("\t"):
              group = f"{first_word} "
              vdev = ""
      actual.sort()
      expected=sorted([
        'zroot /dev/disk/by-partlabel/disk-data1-zfs',
        'zroot mirror /dev/disk/by-partlabel/disk-data2-zfs',
        'zroot mirror /dev/disk/by-partlabel/disk-data3-zfs',
        'dedup /dev/disk/by-partlabel/disk-dedup3-zfs',
        'dedup mirror /dev/disk/by-partlabel/disk-dedup1-zfs',
        'dedup mirror /dev/disk/by-partlabel/disk-dedup2-zfs',
        'special /dev/disk/by-partlabel/disk-special3-zfs',
        'special mirror /dev/disk/by-partlabel/disk-special1-zfs',
        'special mirror /dev/disk/by-partlabel/disk-special2-zfs',
        'logs /dev/disk/by-partlabel/disk-log3-zfs',
        'logs mirror /dev/disk/by-partlabel/disk-log1-zfs',
        'logs mirror /dev/disk/by-partlabel/disk-log2-zfs',
        'cache /dev/disk/by-partlabel/disk-cache-zfs',
        'spares /dev/disk/by-partlabel/disk-spare-zfs',
      ])
      assert actual == expected, f"Incorrect pool layout. Expected:\n\t{'\n\t'.join(expected)}\nActual:\n\t{'\n\t'.join(actual)}"
    '';
  };
  networking.hostId = "8425e349";
}
