{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "luks-btrfs-tpm";
  disko-config = ../example/luks-btrfs-tpm.nix;
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda2");
    machine.succeed("cryptsetup lukdDump /dev/vda2 | grep tpm2");
    machine.succeed("btrfs subvolume list /");
  '';
}
