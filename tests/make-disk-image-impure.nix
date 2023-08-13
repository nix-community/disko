{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.makeDiskImageScript {
  nixosConfig = pkgs.nixos [
    ../module.nix
    ../example/simple-efi.nix
    ({ config, ... }: {
      documentation.enable = false;
      system.stateVersion = config.system.nixos.version;
    })
  ];
  checked = !pkgs.hostPlatform.isRiscV64;
}

