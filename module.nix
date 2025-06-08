{
  config,
  lib,
  pkgs,
  extendModules,
  diskoLib,
  ...
}:
let
  cfg = config.disko;

  vmVariantWithDisko = extendModules {
    modules = [
      ./lib/interactive-vm.nix
      config.disko.tests.extraConfig
    ];
  };
in
{
  imports = [ ./lib/make-disk-image.nix ];

  options.disko = {
    imageBuilder = {
      enableBinfmt = lib.mkOption {
        type = lib.types.bool;
        description = ''
          enable emulation of foreign architecture binaries in the builder.
          Makes it possible to build disk images for a foreign architecture in a VM with native performance.
          Required for the bootloader installation step, which chroots into the target environment.
        '';
        default = false;
      };
      qemu = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        description = ''
          the qemu emulator string used when building disk images via make-disk-image.nix.
          Useful when using binfmt on your build host, and wanting to build disk
          images for a foreign architecture
        '';
        default = null;
        example = lib.literalExpression "\${pkgs.qemu_kvm}/bin/qemu-system-aarch64";
      };

      pkgs = lib.mkOption {
        type = lib.types.attrs;
        description = ''
          the pkgs instance used when building disk images via make-disk-image.nix.
          Useful when the config's kernel won't boot in the image-builder.
        '';
        default = pkgs;
        defaultText = lib.literalExpression "pkgs";
        example = lib.literalExpression "pkgs";
      };

      kernelPackages = lib.mkOption {
        type = lib.types.attrs;
        description = ''
          the kernel used when building disk images via make-disk-image.nix.
          Useful when the config's kernel won't boot in the image-builder.
        '';
        default = config.boot.kernelPackages;
        defaultText = lib.literalExpression "config.boot.kernelPackages";
        example = lib.literalExpression "pkgs.linuxPackages_testing";
      };

      extraRootModules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = ''
          extra kernel modules to pass to the vmTools.runCommand invocation in the make-disk-image.nix builder
        '';
        default = [ ];
        example = [ "bcachefs" ];
      };

      extraPostVM = lib.mkOption {
        type = lib.types.lines;
        description = ''
          extra shell code to execute once the disk image(s) have been successfully created and moved to $out
        '';
        default = ":";
        example = lib.literalExpression ''
          ''${pkgs.zstd}/bin/zstd --compress $out/*raw
          rm $out/*raw
        '';
      };

      extraDependencies = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        description = ''
          list of extra packages to make available in the make-disk-image.nix VM builder, an example might be f2fs-tools
        '';
        default = [ ];
      };

      name = lib.mkOption {
        type = lib.types.str;
        description = "name for the disk images";
        default = "${config.networking.hostName}-disko-images";
        defaultText = "\${config.networking.hostName}-disko-images";
      };

      copyNixStore = lib.mkOption {
        type = lib.types.bool;
        description = "whether to copy the nix store into the disk images we just created";
        default = true;
      };

      extraConfig = lib.mkOption {
        description = ''
          Extra NixOS config for your test. Can be used to specify a different luks key for tests.
          A dummy key is in /tmp/secret.key
        '';
        default = { };
      };

      imageFormat = lib.mkOption {
        type = lib.types.enum [
          "raw"
          "qcow2"
        ];
        description = "QEMU image format to use for the disk images";
        default = "raw";
      };

      useUdevRules = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Copy the udev rules in the VM while building. It can be disabled when unnecessary to speed-up the build,
          and e.g. when cross-building incompatible packages.
        '';
      };
    };

    memSize = lib.mkOption {
      type = lib.types.int;
      description = ''
        size of the memory passed to runInLinuxVM, in megabytes
      '';
      default = 1024;
    };

    devices = lib.mkOption {
      type = diskoLib.toplevel;
      default = { };
      description = "The devices to set up";
    };

    rootMountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/mnt";
      description = "Where the device tree should be mounted by the mountScript";
    };

    enableConfig = lib.mkOption {
      description = ''
        configure nixos with the specified devices
        should be true if the system is booted with those devices
        should be false on an installer image etc.
      '';
      type = lib.types.bool;
      default = true;
    };

    checkScripts = lib.mkOption {
      description = ''
        Whether to run shellcheck on script outputs
      '';
      type = lib.types.bool;
      default = false;
    };

    testMode = lib.mkOption {
      internal = true;
      description = ''
        this is true if the system is being run in test mode.
        like a vm test or an interactive vm
      '';
      type = lib.types.bool;
      default = false;
    };

    tests = {
      bootCommands = lib.mkOption {
        description = ''
          NixOS test script commands to run after the machine has started. Can
          be used to enter an interactive password.
        '';
        type = lib.types.lines;
        default = "";
      };

      efi = lib.mkOption {
        description = ''
          Whether efi is enabled for the `system.build.installTest`.
          We try to automatically detect efi based on the configured bootloader.
        '';
        type = lib.types.bool;
        defaultText = "config.boot.loader.systemd-boot.enable || config.boot.loader.grub.efiSupport";
        default = config.boot.loader.systemd-boot.enable || config.boot.loader.grub.efiSupport;
      };

      enableOCR = lib.mkOption {
        description = ''
          Sets the enableOCR option in the NixOS VM test driver.
        '';
        type = lib.types.bool;
        default = false;
      };

      extraChecks = lib.mkOption {
        description = ''
          extra checks to run in the `system.build.installTest`.
        '';
        type = lib.types.lines;
        default = "";
        example = ''
          machine.succeed("test -e /var/secrets/my.secret")
        '';
      };

      extraConfig = lib.mkOption {
        description = ''
          Extra NixOS config for your test. Can be used to specify a different luks key for tests.
          A dummy key is in /tmp/secret.key
        '';
        default = { };
      };
    };
  };

  options.virtualisation.vmVariantWithDisko = lib.mkOption {
    description = ''
      Machine configuration to be added for the vm script available at `.system.build.vmWithDisko`.
    '';
    inherit (vmVariantWithDisko) type;
    default = { };
    visible = "shallow";
  };

  config = {
    assertions = [
      {
        assertion = config.disko.imageBuilder.qemu != null -> diskoLib.vmToolsSupportsCustomQemu lib;
        message = ''
          You have set config.disko.imageBuild.qemu, but vmTools in your nixpkgs version "${lib.version}"
          does not support overriding the qemu package with the customQemu option yet.
          Please upgrade nixpkgs so that `lib.version` is at least "24.11.20240709".
        '';
      }
    ];

    _module.args.imagePkgs = pkgs;
    _module.args.diskoLib = import ./lib {
      inherit lib;
      rootMountPoint = config.disko.rootMountPoint;
      makeTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
      eval-config = import (pkgs.path + "/nixos/lib/eval-config.nix");
    };

    system.build =
      (cfg.devices._scripts {
        inherit pkgs;
        checked = cfg.checkScripts;
      })
      // (
        let
          throwIfNoDisksDetected =
            _: v:
            if cfg.devices.disk == { } then
              throw "No disks defined, did you forget to import your disko config?"
            else
              v;
        in
        lib.mapAttrs throwIfNoDisksDetected {
          # we keep these old outputs for compatibility
          disko =
            builtins.trace "the .disko output is deprecated, please use .diskoScript instead"
              (cfg.devices._scripts { inherit pkgs; }).diskoScript;
          diskoNoDeps =
            builtins.trace "the .diskoNoDeps output is deprecated, please use .diskoScriptNoDeps instead"
              (cfg.devices._scripts { inherit pkgs; }).diskoScriptNoDeps;

          installTest = diskoLib.testLib.makeDiskoTest {
            inherit extendModules pkgs;
            name = "${config.networking.hostName}-disko";
            disko-config = builtins.removeAttrs config [ "_module" ];
            testMode = "direct";
            bootCommands = cfg.tests.bootCommands;
            efi = cfg.tests.efi;
            enableOCR = cfg.tests.enableOCR;
            extraSystemConfig = cfg.tests.extraConfig;
            extraTestScript = cfg.tests.extraChecks;
          };

          vmWithDisko = lib.mkDefault config.virtualisation.vmVariantWithDisko.system.build.vmWithDisko;
        }
      );

    # we need to specify the keys here, so we don't get an infinite recursion error
    # Remember to add config keys here if they are added to types
    fileSystems = lib.mkIf cfg.enableConfig cfg.devices._config.fileSystems or { };
    boot = lib.mkIf cfg.enableConfig cfg.devices._config.boot or { };
    swapDevices = lib.mkIf cfg.enableConfig cfg.devices._config.swapDevices or [ ];
  };
}
