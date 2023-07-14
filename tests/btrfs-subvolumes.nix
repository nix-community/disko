{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ../lib { }).testLib.makeDiskoTest
}:
makeDiskoTest {
  inherit pkgs;
  name = "btrfs-subvolumes";
  disko-config = ../example/btrfs-subvolumes.nix;
  extraTestScript = ''
    machine.succeed("test -e /test");
    machine.succeed("btrfs subvolume list / | grep -qs 'path test$'");
    machine.succeed("btrfs subvolume list / | grep -qs 'path nix$'");
    machine.succeed("btrfs subvolume list / | grep -qs 'path home$'");
  '';
}

