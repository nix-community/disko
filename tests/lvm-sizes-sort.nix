{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ../lib { }).testLib.makeDiskoTest
}:
makeDiskoTest {
  inherit pkgs;
  name = "lvm-sizes-sort";
  disko-config = ../example/lvm-sizes-sort.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /home");
  '';
}
