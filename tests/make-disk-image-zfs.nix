{
  pkgs ? import <nixpkgs> { },
  ...
}:

(pkgs.nixos [
  ../module.nix
  ../example/zfs-simple-root.nix
  (
    { config, ... }:
    {
      networking.hostId = "00000000";

      # Adds some weight to the closure size to test real world usage
      disko.devices.disk.disk1.imageSize = "5G";
      environment.systemPackages = with pkgs; [
        chromium
        firefox
      ];

      documentation.enable = false;
      system.stateVersion = config.system.nixos.release;
      disko.checkScripts = true;
    }
  )
]).config.system.build.diskoImages
