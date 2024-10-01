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
  '';
}
