{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.makeDiskImageScript {
  nixosConfig = pkgs.nixos [
    ../module.nix
    ../example/simple-efi.nix
    { documentation.enable = false; }
  ];
  checked = true;
}

