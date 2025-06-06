{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
let
  diskoTest = diskoLib.testLib.makeDiskoTest {
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
        kernelPackages = pkgs.linuxPackages_testing;
      };
      environment.systemPackages = [
        pkgs.bcachefs-tools
      ];
    };
    extraSystemConfig = {
      environment.systemPackages = [
        pkgs.jq
      ];
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
      machine.succeed("findmnt -J >&2");

      # Verify existence of mountpoints.
      machine.succeed("mountpoint /");
      machine.succeed("mountpoint /home");
      machine.succeed("mountpoint /nix");
      machine.succeed("mountpoint /home/Documents");
      machine.fail("mountpoint /non-existent");

      # Verify device membership and labels.
      machine.succeed("bcachefs show-super /dev/vda2 | grep 'Devices:' | grep -q '3'");
      machine.succeed("bcachefs show-super /dev/vdd1 | grep 'Devices:' | grep -q '1'");
      machine.succeed("bcachefs show-super /dev/vda2 | grep -qE '^[[:space:]]+Label:[[:space:]]+vdb2[[:space:]]\([[:digit:]]+\)'");
      machine.succeed("bcachefs show-super /dev/vda2 | grep -qE '^[[:space:]]+Label:[[:space:]]+vdc1[[:space:]]\([[:digit:]]+\)'");
      machine.succeed("bcachefs show-super /dev/vda2 | grep -qE '^[[:space:]]+Label:[[:space:]]+vdd1[[:space:]]\([[:digit:]]+\)'");
      machine.succeed("bcachefs show-super /dev/vdd1 | grep -qE '^[[:space:]]+Label:[[:space:]]+vde1[[:space:]]\([[:digit:]]+\)'");
      machine.fail("bcachefs show-super /dev/vda2 | grep 'Label:' | grep -q 'non-existent'");

      # @todo Verify format arguments.

      # Verify mount options from configuration.
      machine.succeed("""
        findmnt -J \
          | jq -e ' \
            .filesystems[] \
              | select(.target == "/") \
              | .options \
              | split(",") \
              | contains(["verbose", "compression=lz4", "background_compression=lz4"]) \
          '
      """);

      machine.succeed("""
        findmnt -J \
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
        findmnt -J \
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
        findmnt -J \
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
        findmnt -J \
          | jq -e ' \
            .filesystems[] \
              | .. \
              | select(.target? == "/home/Documents") \
              | .source \
              | contains("/dev/vdd1") \
          '
      """);

      machine.fail("""
        findmnt -J \
          | jq -e ' \
            .filesystems[] \
              | select(.target == "/") \
              | .source \
              | contains(["/dev/non-existent"]) \
          '
      """);
    '';
  };
in
pkgs.lib.attrsets.recursiveUpdate diskoTest {
  nodes.machine.boot.initrd.extraUtilsCommands = ''
    ${diskoTest.nodes.machine.boot.initrd.extraUtilsCommands}
    # Copy tools for bcachefs
    copy_bin_and_libs ${pkgs.lib.getOutput "mount" pkgs.util-linux}/bin/mount
    copy_bin_and_libs ${pkgs.bcachefs-tools}/bin/bcachefs
    copy_bin_and_libs ${pkgs.bcachefs-tools}/bin/mount.bcachefs
  '';
}
