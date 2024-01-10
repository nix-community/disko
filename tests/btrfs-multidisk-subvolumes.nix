{
  pkgs ? import <nixpkgs> {},
  diskoLib ? pkgs.callPackage ../lib {},
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "btrfs-multidisk";
  disko-config = ../example/btrfs-multidisk-subvolumes.nix;
  extraTestScript = ''
    machine.succeed("test ! -e /test");
    machine.succeed("test -e /home/user");
    machine.succeed("btrfs subvolume list / | grep -qs 'path test$'");
    machine.succeed("btrfs subvolume list / | grep -qs 'path nix$'");
    machine.succeed("btrfs subvolume list / | grep -qs 'path home$'");
  '';
}
