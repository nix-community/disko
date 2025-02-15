{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "luks-btrfs-subvolumes";
  disko-config = ../example/luks-btrfs-subvolumes.nix;
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda2");
    machine.succeed("btrfs subvolume list / | grep -qs 'path nix$'");
    machine.succeed("btrfs subvolume list / | grep -qs 'path home$'");
    machine.succeed("test -e /.swapvol/swapfile");
  '';
}
