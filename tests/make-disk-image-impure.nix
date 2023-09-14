{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.makeDiskImagesScript {
  nixosConfig = pkgs.nixos [
    ../module.nix
    ../example/simple-efi.nix
    ({ config, ... }: {
      documentation.enable = false;
      system.stateVersion = config.system.nixos.version;
    })
  ];
  checked = true;
}

