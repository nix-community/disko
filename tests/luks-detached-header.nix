{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "luks-detached-header";
  disko-config = ../example/luks-detached-header.nix;
  testMode = "direct";
  testBoot = false;
  extraTestScript = ''
    machine.succeed("${pkgs.cryptsetup}/bin/cryptsetup isLuks /dev/disk/by-partlabel/disk-main-luks-header");
    machine.fail("${pkgs.cryptsetup}/bin/cryptsetup isLuks /dev/disk/by-partlabel/disk-main-crypt");
    machine.succeed("mountpoint /mnt");
    machine.succeed("test -e /mnt/home/testfile");
  '';
}
