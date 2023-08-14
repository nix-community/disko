{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "luks-interactive-login";
  disko-config = ../example/luks-interactive-login.nix;
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda2");
  '';
}
