{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "zfs";
  disko-config = ../example/zfs.nix;
  extraInstallerConfig.networking.hostId = "8425e349";
  extraSystemConfig = {
    networking.hostId = "8425e349";
    fileSystems."/zfs_legacy_fs".options = [ "nofail" ]; # TODO find out why we need this!
  };
  extraTestScript = ''
    machine.succeed("test -b /dev/zvol/zroot/zfs_volume");
    machine.succeed("test -b /dev/zvol/zroot/zfs_encryptedvolume");

    def assert_property(ds, property, expected_value):
        out = machine.succeed(f"zfs get -H {property} {ds} -o value").rstrip()
        assert (
            out == expected_value
        ), f"Expected {property}={expected_value} on {ds}, got: {out}"

    assert_property("zroot", "compression", "zstd")
    assert_property("zroot/zfs_fs", "compression", "zstd")
    assert_property("zroot", "com.sun:auto-snapshot", "false")
    assert_property("zroot/zfs_fs", "com.sun:auto-snapshot", "true")
    assert_property("zroot/zfs_volume", "volsize", "10M")
    assert_property("zroot/zfs_encryptedvolume", "volsize", "10M")
    assert_property("zroot/zfs_unmounted_fs", "mountpoint", "none")

    machine.succeed("zfs get name zroot@blank")

    machine.succeed("mountpoint /zfs_fs");
    machine.succeed("mountpoint /zfs_legacy_fs");
    machine.succeed("mountpoint /ext4onzfs");
    machine.succeed("mountpoint /ext4onzfsencrypted");
    machine.succeed("mountpoint /zfs_crypted");
    machine.succeed("zfs get keystatus zroot/encrypted");
    machine.succeed("zfs get keystatus zroot/encrypted/test");
  '';
}
