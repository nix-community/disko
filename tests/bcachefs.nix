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
  extraSystemConfig = {
    environment.systemPackages = [
      pkgs.jq
    ];
  };
  extraTestScript = ''
    # Print debug information.
    machine.succeed("ls -la /subvolumes >&2");
    machine.succeed("lsblk >&2");
    machine.succeed("lsblk -f >&2");
    machine.succeed("mount >&2");
    machine.succeed("bcachefs show-super /dev/vda2 >&2");
    machine.succeed("bcachefs show-super /dev/vdd1 >&2");
    machine.succeed("findmnt --json >&2");

    # Verify subvolume structure.
    machine.succeed("test -d /subvolumes/root");
    machine.succeed("test -d /subvolumes/home");
    machine.succeed("test -d /subvolumes/home/user");
    machine.succeed("test -d /subvolumes/nix");
    machine.succeed("test -d /subvolumes/test");
    machine.fail("test -d /subvolumes/non-existent");

    # Verify existence of mountpoints.
    machine.succeed("mountpoint /");
    machine.succeed("mountpoint /home");
    machine.succeed("mountpoint /nix");
    machine.succeed("mountpoint /home/Documents");
    machine.fail("mountpoint /non-existent");

    # Verify device membership and labels.
    machine.succeed("bcachefs show-super /dev/vda2 | grep 'Devices:' | grep -q '3'");
    machine.succeed("bcachefs show-super /dev/vdd1 | grep 'Devices:' | grep -q '1'");
    machine.succeed("bcachefs show-super /dev/vda2 | grep 'Label:' | grep -q 'vdb2'");
    machine.succeed("bcachefs show-super /dev/vda2 | grep 'Label:' | grep -q 'vdc1'");
    machine.succeed("bcachefs show-super /dev/vda2 | grep 'Label:' | grep -q 'vdd1'");
    machine.succeed("bcachefs show-super /dev/vdd1 | grep 'Label:' | grep -q 'vde1'");
    machine.fail("bcachefs show-super /dev/vda2 | grep 'Label:' | grep -q 'non-existent'");

    # @todo Verify format arguments.

    # Verify mount options from configuration.
    machine.succeed("""
      findmnt --json \
        | jq -e ' \
          .filesystems[] \
            | select(.target == "/") \
            | .options \
            | split(",") \
            | contains(["verbose", "compression=lz4", "background_compression=lz4"]) \
        '
    """);

    machine.succeed("""
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

    # Verify device composition of filesystems.
    machine.succeed("""
      findmnt --json \
        | jq -e ' \
          .filesystems[] \
            | select(.target == "/") \
            | .source | split(":") \
            | contains(["/dev/vda2", "/dev/vdb1", "/dev/vdc1"]) \
        '
    """);

    machine.succeed("""
      findmnt --json \
        | jq -e ' \
          .filesystems[] \
            | .. \
            | select(.target? == "/home/Documents") \
            | .source \
            | contains("/dev/disk/by-uuid/64e50034-ebe2-eaf8-1f93-cf56266a8d86") \
        '
    """);

    machine.fail("""
      findmnt --json \
        | jq -e ' \
          .filesystems[] \
            | select(.target == "/") \
            | .source | split(":") \
            | contains(["/dev/non-existent"]) \
        '
    """);
  '';
}
