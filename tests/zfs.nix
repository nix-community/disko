{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = import ../example/zfs.nix;
  extraTestScript = ''
    machine.succeed("test -b /dev/zvol/zroot/zfs_testvolume");
    machine.succeed("mountpoint /mnt/ext4onzfs");
  '';
}
