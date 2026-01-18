{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
let
  lib = pkgs.lib;
  targetSystem = "armv7l-linux";
  crossAttr = "armv7l-hf-multiplatform";

  diskoConfig = import ../example/cross-zfs.nix;
  testConfig = diskoLib.testLib.prepareDiskoConfig diskoConfig (lib.tail diskoLib.testLib.devices);

  tsp-generator = pkgs.callPackage ../. { checked = false; };
  crossPkgs = pkgs.pkgsCross.${crossAttr};
  hostFormatScript = (tsp-generator._cliFormatCross testConfig) pkgs crossPkgs;
in
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "cross-zfs-${targetSystem}";
  disko-config = ../example/cross-zfs.nix;
  extraInstallerConfig.networking.hostId = "8425e349";
  extraSystemConfig.networking.hostId = "8425e349";
  testMode = "direct";
  testBoot = false;
  extraTestScript = ''
    machine.succeed("uname -m | grep -q x86_64")

    print("Verifying host-native format script for ${targetSystem} target...")
    machine.succeed("test -x ${hostFormatScript}/bin/disko-format")

    def assert_property(ds, property, expected_value):
        out = machine.succeed(f"zfs get -H {property} {ds} -o value").rstrip()
        assert (
            out == expected_value
        ), f"Expected {property}={expected_value} on {ds}, got: {out}"

    assert_property("zroot", "compression", "lz4")
    assert_property("zroot", "com.sun:auto-snapshot", "false")

    print("Cross-format test for ${targetSystem} completed successfully!")
  '';
}
