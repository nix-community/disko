{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ../lib { }).testLib.makeDiskoTest
}:
makeDiskoTest {
  inherit pkgs;
  name = "hybrid";
  disko-config = ../example/hybrid.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
}
