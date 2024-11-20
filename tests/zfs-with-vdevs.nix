{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "zfs-with-vdevs";
  disko-config = ../example/zfs-with-vdevs.nix;
  extraInstallerConfig.networking.hostId = "8425e349";
  extraSystemConfig = {
    networking.hostId = "8425e349";
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
  extraTestScript = ''
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

    # Take the status output and flatten it so that each device is on a single line prefixed with with the group (either
    # the pool name or a designation like log/cache/spare/dedup/special) and first portion of the vdev name (empty for a
    # disk from a single vdev, mirror for devices in a mirror. This makes it easy to verify that the layout is as
    # expected.
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
      'zroot /dev/disk/by-partlabel/disk-data3-zfs',
      'zroot mirror /dev/disk/by-partlabel/disk-data1-zfs',
      'zroot mirror /dev/disk/by-partlabel/disk-data2-zfs',
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
}
