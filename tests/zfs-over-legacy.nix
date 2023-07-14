{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ../lib { }).testLib.makeDiskoTest
}:
makeDiskoTest {
  inherit pkgs;
  name = "zfs-over-legacy";
  disko-config = ../example/zfs-over-legacy.nix;
  extraTestScript = ''
    machine.succeed("test -e /zfs_fs");
    machine.succeed("mountpoint /zfs_fs");
  '';
}

