{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.makeDiskImage {
  nixosConfig = pkgs.nixos [
    ../module.nix
    ../example/simple-efi.nix
  ];
}
