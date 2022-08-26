{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = import ../example/zfs-over-legacy.nix;
  extraTestScript = ''
    machine.succeed("test -e /mnt/zfs_fs");
    machine.succeed("mountpoint /mnt");
    machine.succeed("mountpoint /mnt/zfs_fs");
  '';
}

