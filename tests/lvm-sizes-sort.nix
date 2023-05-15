{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  name = "lvm-sizes-sort";
  disko-config = ../example/lvm-sizes-sort.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /home");
  '';
}
