{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "luks-btrfs-raid-non-root";
  disko-config = ../example/luks-btrfs-raid-non-root.nix;
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda4");
    machine.succeed("cryptsetup isLuks /dev/vda3");
    machine.succeed("cryptsetup isLuks /dev/vda2");
    machine.succeed("cryptsetup isLuks /dev/vdb1");
    machine.succeed("btrfs subvolume list /data");
  '';
}
