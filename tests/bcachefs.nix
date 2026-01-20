{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcachefs";
  disko-config = ../example/bcachefs.nix;
  enableOCR = true;
  bootCommands = ''
    machine.wait_for_text("enter passphrase for /");
    machine.send_chars("secretsecret\n");
    machine.wait_for_text("enter passphrase for /home");
    machine.send_chars("secretsecret\n");
    machine.wait_for_text("enter passphrase for /nix");
    machine.send_chars("secretsecret\n");
  '';
  extraInstallerConfig = {
    boot = {
      kernelPackages = pkgs.linuxPackages_latest;
      supportedFilesystems = [ "bcachefs" ];
    };
  };
  extraSystemConfig = {
    environment.systemPackages = [
      pkgs.jq
    ];
    boot.initrd.extraUtilsCommands = ''
      # Copy tools for bcachefs
      copy_bin_and_libs ${pkgs.lib.getOutput "mount" pkgs.util-linux}/bin/mount
      copy_bin_and_libs ${pkgs.bcachefs-tools}/bin/bcachefs
      copy_bin_and_libs ${pkgs.bcachefs-tools}/bin/mount.bcachefs
    '';
  };
  extraTestScript = ''
    # Print debug information.
    machine.succeed("uname -a >&2");
    machine.succeed("ls -la / >&2");
    machine.succeed("lsblk >&2");
    machine.succeed("lsblk -f >&2");
    machine.succeed("mount >&2");
    machine.succeed("bcachefs show-super /dev/vda2 >&2");
    machine.succeed("bcachefs show-super /dev/vdd1 >&2");
    machine.succeed("findmnt --json >&2");

    # Verify existence of mountpoints.
    machine.succeed("mountpoint /");
    machine.succeed("mountpoint /home");
    machine.succeed("mountpoint /nix");
    machine.succeed("mountpoint /home/Documents");
    machine.fail("mountpoint /non-existent");

    # Verify device membership and labels.
    machine.succeed("bcachefs show-super /dev/vda2 | grep 'Devices:' | grep -q '3'");
    machine.succeed("bcachefs show-super /dev/vdd1 | grep 'Devices:' | grep -q '1'");
    machine.succeed(r"bcachefs show-super /dev/vda2 | grep -qE '^[[:space:]]*Label:[[:space:]]+group_a\.vdb2'");
    machine.succeed(r"bcachefs show-super /dev/vda2 | grep -qE '^[[:space:]]*Label:[[:space:]]+group_a\.vdc1'");
    machine.succeed(r"bcachefs show-super /dev/vda2 | grep -qE '^[[:space:]]*Label:[[:space:]]+group_b\.vdd1'");
    machine.succeed(r"bcachefs show-super /dev/vdd1 | grep -qE '^[[:space:]]*Label:[[:space:]]+group_a\.vde1'");
    machine.fail("bcachefs show-super /dev/vda2 | grep 'Label:' | grep -q 'non-existent'");

    # Verify format arguments.
    # Test that lza4 compression and background_compression options were set for vda2.
    machine.succeed("bcachefs show-super /dev/vda2 | grep -qE '^[[:space:]]*compression:[[:space:]]+lz4'");
    machine.succeed("bcachefs show-super /dev/vda2 | grep -qE '^[[:space:]]*background_compression:[[:space:]]+lz4'");
    # Test that no compression option was set for vdd1.
    machine.succeed("bcachefs show-super /dev/vdd1 | grep -qE '^[[:space:]]*compression:[[:space:]]+none'");

    # Verify mount options from configuration.
    # Test that verbose option was set for "/".
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

    # Test that verbose option was not set for "/home/Documents".
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

    # Test that non-existent option was not set for "/".
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

    # Verify device composition of filesystems.
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
}
