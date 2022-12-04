{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = ../example/tmpfs.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("mountpoint /tmp");
  '';
}
