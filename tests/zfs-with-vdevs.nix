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
