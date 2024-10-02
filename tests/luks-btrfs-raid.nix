{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "luks-btrfs-raid";
  disko-config = ../example/luks-btrfs-raid.nix;
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda2");
    machine.succeed("cryptsetup isLuks /dev/vdb1");
    machine.succeed("btrfs subvolume list /");
  '';
}
