{ pkgs, ... }:
{
  imports = [ ../example/bcachefs.nix ];
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
