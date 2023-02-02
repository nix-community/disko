{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = ../example/hybrid-tmpfs-on-root.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("findmnt / --types tmpfs");
  '';
}
