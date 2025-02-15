{
  pkgs ? import <nixpkgs> { },
  ...
}:

(pkgs.nixos [
  ../module.nix
  ../example/simple-efi.nix
  (
    { config, ... }:
    {
      documentation.enable = false;
      system.stateVersion = config.system.nixos.version;
      disko.memSize = 2048;
      disko.checkScripts = true;
    }
  )
]).config.system.build.diskoImages
