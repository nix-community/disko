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
      system.stateVersion = config.system.nixos.release;
      disko.checkScripts = true;
    }
  )
]).config.system.build.diskoImagesScript
