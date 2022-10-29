{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = ../example/zfs-over-legacy.nix;
  extraTestScript = ''
    machine.succeed("test -e /zfs_fs");
    machine.succeed("mountpoint /zfs_fs");
  '';
}

