{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = import ../example/complex.nix;
  extraTestScript = ''
    machine.succeed("test -b /dev/zroot/zfs_testvolume");
    machine.succeed("test -b /dev/md/raid1p1");


    machine.succeed("mountpoint /mnt");
    machine.succeed("mountpoint /mnt/zfs_fs");
    machine.succeed("mountpoint /mnt/zfs_legacy_fs");
    machine.succeed("mountpoint /mnt/ext4onzfs");
    machine.succeed("mountpoint /mnt/ext4_on_lvm");
  '';
  extraConfig = {
    boot.kernelModules = [ "dm-raid" "dm-mirror" ];
  };
}
