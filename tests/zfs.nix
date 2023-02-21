{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  name = "zfs";
  disko-config = ../example/zfs.nix;
  extraConfig = {
    fileSystems."/zfs_legacy_fs".options = [ "nofail" ]; # TODO find out why we need this!
    boot.zfs.requestEncryptionCredentials = true;
  };
  postDisko = ''
    machine.succeed("zfs set keylocation=prompt zroot/encrypted")
  '';
  enableOCR = true;
  bootCommands = ''
    machine.wait_for_text("(?:passphrase|key) for")
    machine.send_chars("secretsecret\n")
  '';
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
    assert_property("zroot/zfs_unmounted_fs", "mountpoint", "none")

    machine.succeed("mountpoint /zfs_fs");
    machine.succeed("mountpoint /zfs_legacy_fs");
    machine.succeed("mountpoint /ext4onzfs");
    machine.succeed("mountpoint /zfs_crypted");
    machine.succeed("zfs get keystatus zroot/encrypted");
    machine.succeed("zfs get keystatus zroot/encrypted/test");
  '';
}
