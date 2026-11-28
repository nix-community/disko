{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcachefs";
  disko-config = ../example/bcachefs.nix;
  # One unlock unit per mount point races on the shared filesystem, so the
  # number and order of prompts varies: answer them until initrd-fs.target.
  bootCommands = ''
    while True:
        machine.wait_for_console_text("Starting password query on /dev/ttyS0|Reached target Initrd File Systems")
        if "Reached target Initrd File Systems" in machine.get_console_log():
            break
        machine.send_console("secretsecret\n")
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
  };
  extraTestScript = ''
    # Print debug information.
    machine.succeed("uname -a >&2");
    machine.succeed("ls -la / >&2");
    machine.succeed("lsblk >&2");
    machine.succeed("lsblk -f >&2");
    machine.succeed("mount >&2");
    machine.succeed("ls /sys/fs/bcachefs/ >&2");
    machine.succeed("findmnt --json >&2");

    # bcachefs-tools >= 1.33.1 cannot read the superblock from a mounted device 
    def bcachefs_sysfs(mp):
        # --nofsroot leaves out the [/subvolume] of a subvolume mount
        src = machine.succeed(f"findmnt --nofsroot -no SOURCE {mp}").strip().split(":")[0]
        dev = src.rsplit("/", 1)[-1]
        path = machine.succeed(
            "for d in /sys/fs/bcachefs/*/dev-*/block; do "
            f'  if [ "$(basename "$(readlink -f "$d")")" = "{dev}" ]; then '
            '    dirname "$(dirname "$d")"; break; '
            "  fi; "
            "done"
        ).strip()
        assert path, f"no bcachefs sysfs entry found for {mp} (device {dev})"
        return path

    # Verify existence of mountpoints.
    machine.succeed("mountpoint /");
    machine.succeed("mountpoint /home");
    machine.succeed("mountpoint /nix");
    machine.succeed("mountpoint /home/Documents");
    machine.succeed("mountpoint /srv");
    machine.succeed("mountpoint /srv/data");
    machine.fail("mountpoint /non-existent");

    multi_sysfs = bcachefs_sysfs("/")
    single_sysfs = bcachefs_sysfs("/home/Documents")
    encrypted_single_sysfs = bcachefs_sysfs("/srv")

    # Verify device membership.
    multi_devs = int(machine.succeed(f"ls -d {multi_sysfs}/dev-* | wc -l").strip())
    assert multi_devs == 3, f"Expected 3 devices in {multi_sysfs}, got {multi_devs}"
    single_devs = int(machine.succeed(f"ls -d {single_sysfs}/dev-* | wc -l").strip())
    assert single_devs == 1, f"Expected 1 device in {single_sysfs}, got {single_devs}"
    encrypted_single_devs = int(machine.succeed(f"ls -d {encrypted_single_sysfs}/dev-* | wc -l").strip())
    assert encrypted_single_devs == 1, f"Expected 1 device in {encrypted_single_sysfs}, got {encrypted_single_devs}"
    assert encrypted_single_sysfs == bcachefs_sysfs("/srv/data"), "Expected /srv and /srv/data on one filesystem"

    # Verify labels.
    multi_labels = set(machine.succeed(f"cat {multi_sysfs}/dev-*/label").split())
    expected_multi = {"group_a.vdb2", "group_a.vdc1", "group_b.vdd1"}
    assert multi_labels == expected_multi, f"Expected {expected_multi}, got {multi_labels}"
    single_labels = set(machine.succeed(f"cat {single_sysfs}/dev-*/label").split())
    assert single_labels == {"group_a.vde1"}, f"Expected {{'group_a.vde1'}}, got {single_labels}"

    # Verify format arguments via sysfs options.
    multi_comp = machine.succeed(f"cat {multi_sysfs}/options/compression").strip()
    assert multi_comp == "lz4", f"Expected lz4 compression, got {multi_comp!r}"
    multi_bg = machine.succeed(f"cat {multi_sysfs}/options/background_compression").strip()
    assert multi_bg == "lz4", f"Expected lz4 background_compression, got {multi_bg!r}"
    single_comp = machine.succeed(f"cat {single_sysfs}/options/compression").strip()
    assert single_comp == "none", f"Expected no compression, got {single_comp!r}"

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
