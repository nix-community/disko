{ pkgs, ... }:
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

      # Example showing a bcachefs filesystem without subvolumes,
      # which relies on a subvolume in another filesystem being mounted
      # and uses a hard-coded UUID.
      relies_on_external_subvolume = {
        type = "bcachefs_filesystem";
        mountpoint = "/home/Documents";
        uuid = "64e50034-ebe2-eaf8-1f93-cf56266a8d86";
      };
    };
  };
  disko.test = {
    name = "bcachefs";
    enableOCR = true;
    bootCommands = ''
      machine.wait_for_text("enter passphrase for /");
      machine.send_chars("secretsecret\n");
      machine.wait_for_text("enter passphrase for /home");
      machine.send_chars("secretsecret\n");
      machine.wait_for_text("enter passphrase for /nix");
      machine.send_chars("secretsecret\n");
    '';
    nodes.formatter = {
      boot = {
        kernelPackages = pkgs.linuxPackages_latest;
        supportedFilesystems = [ "bcachefs" ];
      };
    };
    nodes.machine = {
      environment.systemPackages = [ pkgs.jq ];
      boot.initrd.extraUtilsCommands = ''
        # Copy tools for bcachefs
        copy_bin_and_libs ${pkgs.lib.getOutput "mount" pkgs.util-linux}/bin/mount
        copy_bin_and_libs ${pkgs.bcachefs-tools}/bin/bcachefs
        copy_bin_and_libs ${pkgs.bcachefs-tools}/bin/mount.bcachefs
      '';
    };
    extraChecks = ''
      # Print debug information.
      machine.succeed("uname -a >&2");
      machine.succeed("ls -la / >&2");
      machine.succeed("lsblk >&2");
      machine.succeed("lsblk -f >&2");
      machine.succeed("mount >&2");
      # We need to manually unlock /dev/vda2 for some reason
      # even though it should already get unlocked by bootCommands
      machine.succeed(r'printf "secretsecret" | bcachefs unlock -k session /dev/vda2 >&2');
      machine.succeed("bcachefs show-super /dev/vda2 >&2");
      machine.succeed("bcachefs show-super /dev/vdd1 >&2");
      machine.succeed("findmnt --json >&2");

      machine.succeed("mountpoint /");
      machine.succeed("mountpoint /home");
      machine.succeed("mountpoint /nix");
      machine.succeed("mountpoint /home/Documents");
      machine.fail("mountpoint /non-existent");

      machine.succeed("bcachefs show-super /dev/vda2 | grep 'Devices:' | grep -q '3'");
      machine.succeed("bcachefs show-super /dev/vdd1 | grep 'Devices:' | grep -q '1'");
      machine.succeed(r"bcachefs show-super /dev/vda2 | grep -qE '^[[:space:]]*Label:[[:space:]]+group_a\.vdb2'");
      machine.succeed(r"bcachefs show-super /dev/vda2 | grep -qE '^[[:space:]]*Label:[[:space:]]+group_a\.vdc1'");
      machine.succeed(r"bcachefs show-super /dev/vda2 | grep -qE '^[[:space:]]*Label:[[:space:]]+group_b\.vdd1'");
      machine.succeed(r"bcachefs show-super /dev/vdd1 | grep -qE '^[[:space:]]*Label:[[:space:]]+group_a\.vde1'");
      machine.fail("bcachefs show-super /dev/vda2 | grep 'Label:' | grep -q 'non-existent'");

      machine.succeed("bcachefs show-super /dev/vda2 | grep -qE '^[[:space:]]*compression:[[:space:]]+lz4'");
      machine.succeed("bcachefs show-super /dev/vda2 | grep -qE '^[[:space:]]*background_compression:[[:space:]]+lz4'");
      machine.succeed("bcachefs show-super /dev/vdd1 | grep -qE '^[[:space:]]*compression:[[:space:]]+none'");

      machine.succeed("""
        findmnt --json \
          | jq -e ' \
            .filesystems[] \
              | select(.target == "/") \
              | .options \
              | split(",") \
              | contains(["verbose"]) \
          '
      """);

      machine.fail("""
        findmnt --json \
          | jq -e ' \
            .filesystems[] \
              | .. \
              | select(.target? == "/home/Documents") \
              | .options \
              | split(",") \
              | contains(["verbose"]) \
          '
      """);

      machine.fail("""
        findmnt --json \
          | jq -e ' \
            .filesystems[] \
              | select(.target == "/") \
              | .options \
              | split(",") \
              | contains(["non-existent"]) \
          '
      """);

      machine.succeed("""
        findmnt --json \
          | jq -e ' \
            .filesystems[] \
              | select(.target == "/") \
              | .source \
              | contains("/dev/vda2") \
                and contains("/dev/vdb1") \
                and contains("/dev/vdc1") \
                and contains("[/subvolumes/root]") \
          '
      """);

      machine.succeed("""
        findmnt --json \
          | jq -e ' \
            .filesystems[] \
              | .. \
              | select(.target? == "/home/Documents") \
              | .source \
              | contains("/dev/vdd1") \
          '
      """);

      machine.fail("""
        findmnt --json \
          | jq -e ' \
            .filesystems[] \
              | select(.target == "/") \
              | .source \
              | contains(["/dev/non-existent"]) \
          '
      """);
    '';
  };
}
