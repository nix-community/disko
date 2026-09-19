{
  config,
  modulesPath,
  pkgs,
  ...
}@outerModuleArgs:
let
  # When you run “nixos-rebuild build-image”, nixos-rebuild will give you a
  # list of supported image variants. This module adds a new supported image
  # variant to that list. In order to add a new supported image variant to that
  # list, we need to set the image.modules.<new-image-variant-name> option. Our
  # new image variant is named disko-unattended-install-iso, so we need to set
  # the image.modules.disko-unattended-install-iso option.
  #
  # Unfortunately, when you set image.modules.disko-unattended-install-iso, it
  # will merge that module with the rest of your NixOS configuration. So if you
  # enable KDE Plasma in your main configuration, then it will enable KDE
  # Plasma on the unattended install ISO. This is not what we want.
  #
  # In order to work around that problem, we create a “realUnattendedInstallerConfiguration”.
  # The realUnattendedInstallerConfiguration does NOT automatically inherit
  # things from the main NixOS configuration. The realUnattendedInstallerConfiguration
  # is based solely off of things specified in image.modules.disko-unattended-install-iso.
  # Later on, we forcibly set image.modules.disko-unattended-install-iso.system.build.image
  # so that users get an ISO that is built from the realUnattendedInstallerConfiguration.
  realUnattendedInstallerConfiguration = import "${modulesPath}/.." {
    configuration = {
      imports = [ config.image.modules.disko-unattended-install-iso ];

      overrideSystemBuildImage = false;
    };
    inherit (pkgs.stdenv.hostPlatform) system;
  };
in
{
  image.modules.disko-unattended-install-iso =
    {
      config,
      lib,
      modulesPath,
      ...
    }:
    {
      imports = [
        ../module.nix
        "${modulesPath}/installer/cd-dvd/installation-cd-base.nix"
      ];

      options.overrideSystemBuildImage = lib.mkOption {
        type = lib.types.bool;
        default = true;
        internal = true;
      };

      config =
        let
          installScriptPrettyName = config.systemd.services.unattendedInstall.description;
        in
        {
          system.build.image = lib.mkIf config.overrideSystemBuildImage (
            lib.mkForce realUnattendedInstallerConfiguration.config.system.build.image
          );

          disko.unattendedInstall = {
            enable = true;
            # Originally, I tried doing this for this next part:
            #
            # deployeeConfiguration.config = outerModuleArgs.config;
            #
            # Doing that caused an evaluation error and a whole bunch of
            # evaluation warnings. As a workaround, we set
            # deployeeConfiguration.config to an attribute set that contains
            # only the attributes that are actually needed by the
            # ./unattended-install.nix.
            deployeeConfiguration.config = {
              nix.package = outerModuleArgs.config.nix.package;
              system.build = {
                inherit (outerModuleArgs.config.system.build) destroyFormatMount nixos-install toplevel;
              };
            };
          };
          specialisation =
            lib.mkIf (config.disko.unattendedInstall.startAtBoot == "separate-boot-menu-item")
              {
                unattendedInstall.configuration.isoImage.configurationName = lib.mkDefault installScriptPrettyName;
              };

          # For the most part, it doesn’t make sense to inherit things from the
          # outer NixOS configuration, so we avoid doing so. That being said,
          # there are a few things that would be good to inherit. We manually
          # inherit them below.
          nix.package = lib.mkDefault outerModuleArgs.config.nix.package;
          networking.hostName =
            let
              installScriptPrettyNameNoSpaces = lib.replaceString " " "-" installScriptPrettyName;
              outerHostName = outerModuleArgs.config.networking.hostName;
              desiredHostName = "${installScriptPrettyNameNoSpaces}-For-${outerHostName}";
              # See the description for networking.hostName.
              maximumHostNameLength = 63;
            in
            lib.mkDefault (lib.substring 0 maximumHostNameLength desiredHostName);
          # This next one prevents the following situation: a user uses
          # bcachefs (for example) in disko.devices.disk.<whatever>. Their
          # NixOS configuration works perfectly fine, but the disko unattended
          # install ISO does not because NixOS installation ISOs don’t support
          # bcachefs by default.
          boot.supportedFilesystems = lib.mkDefault outerModuleArgs.config.boot.supportedFilesystems;
        };
    };
}
