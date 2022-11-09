{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = ../example/btrfs-subvolumes.nix;
  extraTestScript = ''
    machine.succeed("test -e /test");
    machine.succeed("btrfs subvolume list / | grep -qs 'path test$'");
  '';
}

