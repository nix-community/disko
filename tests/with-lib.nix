{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ../lib { }).testLib.makeDiskoTest
}:
makeDiskoTest {
  inherit pkgs;
  name = "with-lib";
  disko-config = ../example/with-lib.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
  efi = false;
}
