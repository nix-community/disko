# this is a regression test for https://github.com/nix-community/disko/issues/52
{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "multi-device-no-deps";
  disko-config = ../example/multi-device-no-deps.nix;
  testBoot = false;
  extraTestScript = ''
    machine.succeed("mountpoint /mnt/a");
    machine.succeed("mountpoint /mnt/b");
  '';
}
