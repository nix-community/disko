{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = import ../example/zfs.nix;
  extraTestScript = ''
    machine.succeed("test -b /dev/zvol/zroot/zfs_testvolume");

    def assert_property(ds, property, expected_value):
        out = machine.succeed(f"zfs get -H {property} {ds} -o value").rstrip()
        assert (
            out == expected_value
        ), f"Expected {property}={expected_value} on {ds}, got: {out}"

    assert_property("zroot", "compression", "lz4")
    assert_property("zroot/zfs_fs", "compression", "lz4")
    assert_property("zroot", "com.sun:auto-snapshot", "false")
    assert_property("zroot/zfs_fs", "com.sun:auto-snapshot", "true")
    assert_property("zroot/zfs_testvolume", "volsize", "10M")

    # FIXME: we cannot mount rootfs yet
    #machine.succeed("mountpoint /mnt");
    machine.succeed("mountpoint /mnt/zfs_fs");
    machine.succeed("mountpoint /mnt/zfs_legacy_fs");
    machine.succeed("mountpoint /mnt/ext4onzfs");
  '';
}
