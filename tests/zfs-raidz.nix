{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  name = "zfs-raidz";
  disko-config = ../example/zfs-raidz.nix;
  enableOCR = true;
  extraConfig = {
    boot.zfs.forceImportAll = true;
  };
  extraTestScript = ''

    def assert_property(ds, property, expected_value):
        out = machine.succeed(f"zfs get -H {property} {ds} -o value").rstrip()
        assert (
            out == expected_value
        ), f"Expected {property}={expected_value} on {ds}, got: {out}"


    machine.fail("test -e /zroot");
    machine.fail("test -e /zraid");

    assert_property("zroot/root", "compression", "lz4")
    assert_property("zroot/root", "mountpoint", "legacy")

    machine.succeed("test ! -e /media");
    machine.succeed("mountpoint /media");
    assert_property("zraid/media", "compression", "lz4")
    assert_property("zraid/media", "mountpoint", "legacy")

    machine.succeed("test ! -e /nextcloud");
    machine.succeed("mountpoint /nextcloud");
    assert_property("zraid/nextcloud", "compression", "lz4")
    assert_property("zraid/nextcloud", "mountpoint", "legacy")
    assert_property("zraid/nextcloud", "com.sun:auto-snapshot", "false")
    assert_property("zraid/nextcloud", "com.sun:auto-snapshot:daily", "true,keep=32")

  '';
}

