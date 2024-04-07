{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "btrfs-only-root-subvolume";
  disko-config = ../example/btrfs-only-root-subvolume.nix;
  extraTestScript = ''
    machine.succeed("btrfs subvolume list /");
  '';
}
