{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "btrfs-subvolumes";
  disko-config = ../example/btrfs-subvolumes.nix;
  extraTestScript = ''
    machine.succeed("test ! -e /test");
    machine.succeed("test -e /home/user");
    machine.succeed("btrfs subvolume list / | grep -qs 'path test$'");
    machine.succeed("btrfs subvolume list / | grep -qs 'path nix$'");
    machine.succeed("btrfs subvolume list / | grep -qs 'path home$'");
    machine.succeed("test -e /.swapvol/swapfile");
    machine.succeed("test -e /.swapvol/rel-path");
    machine.succeed("test -e /partition-root/swapfile");
    machine.succeed("test -e /partition-root/swapfile1");
  '';
}
