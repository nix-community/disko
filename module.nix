{ config, lib, pkgs, extendModules, ... }@args:
let
  diskoLib = import ./lib {
    inherit lib;
    rootMountPoint = config.disko.rootMountPoint;
    makeTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
    eval-config = import (pkgs.path + "/nixos/lib/eval-config.nix");
  };
  cfg = config.disko;
in
{
  options.disko = {
    imageBuilderQemu = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = ''
        the qemu emulator string used when building disk images via make-disk-image.nix.
        Useful when using binfmt on your build host, and wanting to build disk
        images for a foreign architecture
      '';
      default = null;
      example = lib.literalExpression "''${pkgs.qemu_kvm}/bin/qemu-system-aarch64";
    };
    imageBuilderPkgs = lib.mkOption {
      type = lib.types.attrs;
      description = ''
        the pkgs instance used when building disk images via make-disk-image.nix.
        Useful when the config's kernel won't boot in the image-builder.
      '';
      default = pkgs;
      example = lib.literalExpression "pkgs";
    };
    imageBuilderKernelPackages = lib.mkOption {
      type = lib.types.attrs;
      description = ''
        the kernel used when building disk images via make-disk-image.nix.
        Useful when the config's kernel won't boot in the image-builder.
      '';
      default = config.boot.kernelPackages;
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
      type = lib.types.str;
      description = ''
        extra shell code to execute once the disk image(s) have been succesfully created and moved to $out
      '';
      default = "";
      example = lib.literalExpression ''
        ''${pkgs.zstd}/bin/zstd --compress $out/*raw
        rm $out/*raw
      '';
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
    extraDependencies = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      description = ''
        list of extra packages to make available in the make-disk-image.nix VM builder, an example might be f2fs-tools
      '';
      default = [ ];
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
    tests = {
      efi = lib.mkOption {
        description = ''
          Whether efi is enabled for the `system.build.installTest`.
          We try to automatically detect efi based on the configured bootloader.
        '';
        type = lib.types.bool;
        defaultText = "config.boot.loader.systemd-boot.enable || config.boot.loader.grub.efiSupport";
        default = config.boot.loader.systemd-boot.enable || config.boot.loader.grub.efiSupport;
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
  config = lib.mkIf (cfg.devices.disk != { }) {
    system.build = (cfg.devices._scripts { inherit pkgs; checked = cfg.checkScripts; }) // {

      # we keep these old outputs for compatibility
      disko = builtins.trace "the .disko output is deprecated, please use .diskoScript instead" (cfg.devices._scripts { inherit pkgs; }).diskoScript;
      diskoNoDeps = builtins.trace "the .diskoNoDeps output is deprecated, please use .diskoScriptNoDeps instead" (cfg.devices._scripts { inherit pkgs; }).diskoScriptNoDeps;

      diskoImages = diskoLib.makeDiskImages {
        nixosConfig = args;
      };
      diskoImagesScript = diskoLib.makeDiskImagesScript {
        nixosConfig = args;
      };

      installTest = diskoLib.testLib.makeDiskoTest {
        inherit extendModules pkgs;
        name = "${config.networking.hostName}-disko";
        disko-config = builtins.removeAttrs config [ "_module" ];
        testMode = "direct";
        efi = cfg.tests.efi;
        extraSystemConfig = cfg.tests.extraConfig;
        extraTestScript = cfg.tests.extraChecks;
      };
    };


    # we need to specify the keys here, so we don't get an infinite recursion error
    # Remember to add config keys here if they are added to types
    fileSystems = lib.mkIf cfg.enableConfig cfg.devices._config.fileSystems or { };
    boot = lib.mkIf cfg.enableConfig cfg.devices._config.boot or { };
    swapDevices = lib.mkIf cfg.enableConfig cfg.devices._config.swapDevices or [ ];
  };
}
