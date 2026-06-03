{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  extraKernelParams = [ "console=ttyS0" ];
in
{
  imports = [
    ../../module.nix
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  options.successfulInstallSignal = lib.mkOption {
    type = lib.types.str;
    description = ''
      The test will check to see if this string gets output to the deployee’s
      serial console. If it does, then that indicates that the installation was
      successful.
    '';
  };

  config = {
    boot = {
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      kernelParams = extraKernelParams ++ [ "systemd.unit=displaySuccessfulInstallSignal.service" ];
    };

    system.stateVersion = config.system.nixos.release;

    disko.devices.disk.main = {
      device = "/dev/vda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          efiSystemPartition = {
            type = "EF00";
            size = "512M";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };

    networking.hostName = "deployee";

    systemd.services.displaySuccessfulInstallSignal = {
      script = ''
        printf 'Successful install signal: %s\n' ${lib.escapeShellArg config.successfulInstallSignal}
      '';
      unitConfig.SuccessAction = "poweroff";
      serviceConfig = {
        StandardOutput = "journal+console";
        StandardError = "journal+console";
      };
    };

    image.modules.disko-unattended-install-iso = {
      boot.kernelParams = extraKernelParams;
      disko.unattendedInstall = {
        startAtBoot = "on";
        # This next part prevents nixos-install from wasting time by trying
        # (and failing) to connect to cache.nixos.org.
        extraNixOSInstallArgs = [
          "--option"
          "substituters"
          ""
        ];
      };
    };
  };
}
