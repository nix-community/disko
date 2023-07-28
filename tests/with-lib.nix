{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "with-lib";
  disko-config = ../example/with-lib.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
  efi = false;
}
