{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.disko.unattendedInstall;
  installScriptName = "disko-unattended-nixos-installer";
  installScriptPrettyName = config.systemd.services.unattendedInstall.description;
  motdPath = "/var/lib/${installScriptName}/motd";
  runInstallerCommand = "systemctl start unattendedInstall.service";
  viewLogsCommand = "journalctl --boot --unit=unattendedInstall.service --unit=unattendedInstallAtBoot.service";
in
{
  imports = [ ./unattended-install-iso.nix ];
  options.disko.unattendedInstall = {
    enable = lib.mkOption {
      type = lib.types.bool;
      description = ''
        Enable configuration options for doing automatic unattended
        installations of NixOS.

        When using any of the {option}`disko.unattendedInstall.*` options, you
        must have two NixOS configurations:

        1. The deployee configuration. The depolyee configuration gets used as
           the first generation for the freshly installed NixOS system. See
           {option}`disko.unattendedInstall.deployeeConfiguration`.

        2. The unattended installer configuration. The unattended installer
           configuration gets activated when you boot into an unattended
           installer.

        For the deployee configuration, this option should be set to `false`.
        For the unattended installer configuration, this option should be set
        to `true`.

        When this option is set to `true`, two systemd services will be added
        to your system: `unattendedInstall.service` and
        `unattendedInstallAtBoot.service`. You can manually start
        `unattendedInstall.service` in order to perform an unattended
        installation (this is useful for debugging). You can automatically
        start `unattendedInstallAtBoot.service` at boot in order to make the
        process completely unattended (see
        {option}`disko.unattendedInstall.startAtBoot` for details). Both
        `unattendedInstall.service` and `unattendedInstallAtBoot.service` do
        pretty much the same thing.

        Technically, you can manually start
        `unattendedInstallAtBoot.service`, but it’s not recommended.
        `unattendedInstallAtBoot.service` will output all of its logs to the
        console. When the system is booting, this is a good thing because it
        allows you to see what is going on. After the system has finished
        booting, this is a bad thing because the stream of text makes it
        difficult to use TTYs.
      '';
      default = false;
      example = true;
    };
    deployeeConfiguration = lib.mkOption {
      type = lib.types.raw;
      description = ''
        The NixOS configuration that will be used as the first generation of
        the new NixOS installation that will be created by the unattended
        installation process.
      '';
      example = lib.literalMD ''
        If you aren’t using any experimental features for your NixOS
        configuration, then you would set this option to something like this:

        ```nix
        import "''${modulesPath}/.." {
          configuration = ./configuration.nix;
        }
        ```

        If you’re using [the flakes experimental feature](https://nix.dev/manual/nix/2.34/development/experimental-features.html#xp-feature-flakes)
        for your NixOS configuration, then you would set this option to
        something like this:

        ```nix
        self.nixosConfigurations.my-computer
        ```
      '';
    };
    startAtBoot = lib.mkOption {
      type = lib.types.enum [
        "off"
        "on"
        "separate-boot-menu-item"
      ];
      description = ''
        Whether or not to automatically start performing an unattended
        installation at boot.

        - When this option is set to `"off"`, the unattended installer will not
          start at boot. In order to perform an unattended installation, the
          user will have to manually start `unattendedInstall.service` after
          logging in. Setting this option to `"off"` is useful for debugging.

        - When this option is set to `"on"`, the unattended installer will
          automatically start at boot. This allows for a completely unattended
          installation.

        - When this option is set to `"separate-boot-menu-item"`, a new
          `unattendedInstall` boot menu item will be created. If the user
          selects the `unattendedInstall` boot menu item, then the unattended
          installer will start automatically at boot. If the user selects the
          default boot menu item, then the unattended installer will not start
          automatically at boot.

          `"separate-boot-menu-item"` is useful for preventing infinite boot
          loops. When this option is set to `"on"`, there’s a chance that a
          computer will boot into the unattended installer, finish the
          installation successfully, automatically reboot, boot back into the
          unattended installer, and continue looping through that process until
          someone notices and manually stops it. Setting this option to
          `"separate-boot-menu-item"` prevents that problem from happening. If
          the computer happens to reboot into the unattended installer after
          the installation has finished successfully, it will select the
          default boot option which won’t automatically run the unattended
          installer.
      '';
      default = "separate-boot-menu-item";
      example = "off";
    };
    successfulBootInstallNextStep = lib.mkOption {
      type = lib.types.enum [
        "continue-booting"
        "poweroff"
        "reboot"
      ];
      description = ''
        If the unattended installer is started at boot and it finishes
        successfully, then what happens next? This option controls what happens
        next.

        - When this option is set to `"continue-booting"`, the systemd
          `default.target` unit will be started. This is mainly useful for
          debugging.

        - When this option is set to `"poweroff"`, the system will be shut
          down.

        - When this option is set to `"reboot"`, the system will restart.
      '';
      default = "poweroff";
      example = "reboot";
    };
    motdHints = lib.mkOption {
      type = lib.types.bool;
      description = ''
        When this option is set to `true`, the MOTD that gets displayed when
        users log in will be used to give users hints about unattended
        installations. For example, if the unattended installer was not started
        at boot, then the MOTD will tell users how to start it. Or, if the
        unattended installer was started at boot and finished unsuccessfully,
        then the MOTD will tell users that the installer failed and explain how
        to check the installer’s logs.
      '';
      default = true;
      example = false;
    };
    extraNixOSInstallArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = ''
        The unattended installer will run {command}`nixos-install` as a part of
        the unattended installation process. This option allows you to pass
        additional command-line arguments to {command}`nixos-install`.
      '';
      default = [ ];
      example = [ "--no-channel-copy" ];
    };
  };
  config = lib.mkIf cfg.enable {
    users.motdFile = lib.mkIf cfg.motdHints motdPath;
    systemd = {
      tmpfiles.settings."10-initial-MOTD"."${motdPath}"."f".argument = ''
        You have successfully booted into a NixOS configuration that can be
        used to perform unattended installs of NixOS. The unattended installer
        has not been started yet (at least, not since the last boot).

        You can start the unattended installer by running this command as root:

          # ${runInstallerCommand}

        You can check the unattended installer’s logs by running this command
        as root:

          # ${viewLogsCommand}

        NOTE: If you recently did an unattended installation, then your
        computer may have successfully finished the unattended installation,
        rebooted and then booted back into the installation medium.
      '';
      services =
        let
          installScript = pkgs.writeShellApplication {
            name = installScriptName;
            runtimeInputs = [
              # This first one is needed or else we will get this error…
              #
              # > nix-env: command not found
              #
              # …when we try to run nixos-install.
              cfg.deployeeConfiguration.config.nix.package
              cfg.deployeeConfiguration.config.system.build.destroyFormatMount
              cfg.deployeeConfiguration.config.system.build.nixos-install
            ];
            text = ''
              set -euo pipefail

              ${lib.toShellVars {
                inherit (cfg) extraNixOSInstallArgs;
                inherit motdPath;
                systemDerivation = cfg.deployeeConfiguration.config.system.build.toplevel;
                inProgressMOTD = ''
                  The ${installScriptPrettyName} is currently running. You can
                  check on its progress by running this command as root:

                    # ${viewLogsCommand}
                '';
                failureMOTD = ''
                  The ${installScriptPrettyName} has failed. You can check its
                  logs by running this command as root:

                    # ${viewLogsCommand}

                  You can try to run the ${installScriptPrettyName} again by
                  running this command as root:

                    # ${runInstallerCommand}
                '';
                successMOTD = ''
                  The ${installScriptPrettyName} has finished installing NixOS
                  successfully. You can view the logs for the installer by
                  running this command as root:

                    # ${viewLogsCommand}

                  At this point, you can shutdown the system by running this
                  command as root:

                    # systemctl poweroff

                  After you have shut down the system, remove the installation
                  medium. Turn the system back on in order to boot into your
                  new installation of NixOS!
                '';
              }}
              # We could use “set -x” in order to achieve a similar effect, but
              # disko-destroy-format-mount already uses “set -x”. I’m using my
              # own custom output format in order to make things less
              # confusing.
              function show_and_run_command {
                printf '# '
                printf '%q ' "$@"
                printf '\n'
                "$@"
              }

              echo 'Starting unattended NixOS installation…'
              printf '%s' "$inProgressMOTD" > "$motdPath"
              wasSuccessful=false
              trap "
                if [ \"\$wasSuccessful\" = true ]
                then
                  printf '%s' \"\$successMOTD\" > \"\$motdPath\"
                else
                  printf '%s' \"\$failureMOTD\" > \"\$motdPath\"
                fi
              " EXIT

              show_and_run_command disko-destroy-format-mount --yes-wipe-all-disks
              # When using nixos-install, you typically give nixos-install a
              # Nix expression that represents a NixOS configuration (e.g., a
              # path to a system.nix file or a flake URL). nixos-install will
              # then evaluate and build that Nix expression.
              #
              # In this situation, we are using --system in order to give it a
              # system derivation instead of a Nix expression. This means that
              # we won’t have to evaluate or build anything. Doing this has a
              # few advantages:
              #
              # 1. Skiping the evaluation and building steps saves time.
              #
              # 2. If we did not skip evaluating and building the deployee
              #    configuration here, then there’s a good chance that we would
              #    end up evaluating and building it twice. The first time, the
              #    deployee configuration would be evaluated and built on the
              #    machine that is being used to create the unattended
              #    installation medium. That first time would technically be
              #    optional, but many users would do it in order to make sure
              #    that their deployee configuration is not broken. The second
              #    time, the deployee configuration would be evaluated and
              #    built during the unattended installation. In this situation,
              #    doing the same thing twice is not helpful. It’s a waste of
              #    resources. Additionally, if the unattended install medium
              #    gets used more than once, then the evaluating and building
              #    steps would happen more than twice which would waste even
              #    more resources.
              #
              # 3. It’s very difficult to make sure that any Nix expression
              #    that a user might use for their deployee configuration will
              #    evaluate successfully. For example, what if the Nix
              #    expression uses buitins.fetchGit with an “ssh://” URL? It’s
              #    very possible that that “ssh://” URL will work fine when
              #    evaluation is done on the user’s main machine but will fail
              #    when done on an unattended install medium because the
              #    install medium’s SSH key is not trusted. We can sidestep
              #    problems like that one by avoiding evaluation.
              #
              # 4. If we gave nixos-install a Nix expression, then we would
              #    have to switch between using --file and --flake depdending
              #    on whether or not the deployee configuration was specified
              #    in a flake. Using --system means that we don’t have to have
              #    to worry about whether the deployee configuration was
              #    specified in a flake or not.
              #
              # 5. By using --system here, we end up evaluating and building
              #    the deployee configuration on the machine that builds the
              #    unattended install medium. That machine is likely to have
              #    more paths in its Nix store than the unattended install
              #    medium itself. If we were to build on the unattended install
              #    medium, then it’s likely that we would have to download and
              #    build more paths because those paths were not already in the
              #    unattended install medium’s Nix store.
              show_and_run_command nixos-install \
                --system "$systemDerivation" \
                --no-root-password \
                "''${extraNixOSInstallArgs[@]}"
              wasSuccessful=true
              echo 'The unattended NixOS installation finished successfully!'
            '';
          };
          unattendedInstallDependencies = [
            # This service assumes that the MOTD file already exists before it
            # runs. systemd-tmpfiles-setup.service is the thing that makes sure
            # that the MOTD file exists.
            "systemd-tmpfiles-setup.service"
          ];
          baseUnattendedInstallService = {
            wants = unattendedInstallDependencies;
            after = unattendedInstallDependencies;
            serviceConfig.ExecStart = lib.getExe installScript;
          };
          commonConfig = {
            # This service creates the initial MOTD file. If the MOTD file is
            # actually going to get used, then it needs to exist before getty
            # is started.
            systemd-tmpfiles-setup.before = lib.mkIf cfg.motdHints [ "getty-pre.target" ];

            unattendedInstall = baseUnattendedInstallService;
            unattendedInstallAtBoot = baseUnattendedInstallService;
          };
          configThatDiffersForRegularVsAtBoot = {
            unattendedInstall = {
              # This part tries to prevent people from accidentally running two
              # installers at the same time.
              conflicts = [ "unattendedInstallAtBoot.service" ];
              before = [ "unattendedInstallAtBoot.service" ];

              description = "Disko Unattended NixOS Installer";
            };
            unattendedInstallAtBoot = {
              conflicts = [ "unattendedInstall.service" ];
              after = [ "unattendedInstall.service" ];

              description = installScriptPrettyName + " (running during boot)";
              unitConfig = {
                OnSuccess = lib.mkIf (cfg.successfulBootInstallNextStep == "continue-booting") "default.target";
                OnFailure = "default.target";
                SuccessAction = lib.mkIf (
                  cfg.successfulBootInstallNextStep != "continue-booting"
                ) cfg.successfulBootInstallNextStep;
              };
              # This next part make it so that the user can see that the
              # unattended installer is making progress while it’s running. I’m
              # only enabling this for the version of the service that runs at
              # boot so that the user’s terminal doesn’t get overwritten with a
              # flood of messages if they run the unattended installer manually
              # from a tty.
              serviceConfig = {
                StandardOutput = "journal+console";
                StandardError = "journal+console";
              };
            };
          };
        in
        lib.mkMerge [
          commonConfig
          configThatDiffersForRegularVsAtBoot
        ];
    };
    boot.kernelParams = lib.mkIf (cfg.startAtBoot == "on") [
      "systemd.unit=unattendedInstallAtBoot.service"
    ];
    specialisation = lib.mkIf (cfg.startAtBoot == "separate-boot-menu-item") {
      unattendedInstall.configuration.disko.unattendedInstall.startAtBoot = lib.mkForce "on";
    };
  };
}
