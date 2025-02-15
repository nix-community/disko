# this is a regression test for https://github.com/nix-community/disko/issues/52
{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "negative-size";
  disko-config = ../example/negative-size.nix;
  testBoot = false;
  extraTestScript = ''
    machine.succeed("mountpoint /mnt");
  '';
}
