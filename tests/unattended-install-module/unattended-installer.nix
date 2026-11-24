{ modulesPath, pkgs, ... }:
{
  imports = [ ./common.nix ];

  virtualisation = {
    emptyDiskImages = [ 4096 ];
    useBootLoader = true;
    useEFIBoot = true;
  };

  disko.unattendedInstall = {
    enable = true;
    deployeeConfiguration = import "${modulesPath}/.." {
      configuration = ./deployee.nix;
      inherit (pkgs.stdenv.hostPlatform) system;
    };
    startAtBoot = "on";
    successfulBootInstallNextStep = "continue-booting";
  };

  networking.hostName = "unattended-installer";
}
