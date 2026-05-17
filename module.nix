{
  config,
  lib,
  pkgs,
  extendModules,
  diskoLib,
  modulesPath,
  ...
}:
let
  cfg = config.disko;

  vmVariantWithDisko = extendModules {
    modules = [ ./lib/interactive-vm.nix ];
  };

  # `evalTest` (not `runTest`) because we need the evalModules result's
  # `.type` to declare `options.disko.test` as a submodule. `runTest`'s
  # `.type` is the string "derivation", unusable as an option type.
  nixos-lib = import (pkgs.path + "/nixos/lib") { inherit lib; };
  installTestEval = nixos-lib.evalTest {
    imports = [
      ./lib/install-test.nix
      {
        hostPkgs = pkgs;
        node.pkgs = pkgs;
        _module.args = {
          inherit diskoLib;
          diskoDevices = config.disko.devices;
        };
      }
      {
        defaults.networking.hostId = lib.mkIf (config.networking.hostId != null) config.networking.hostId;
      }
    ];
  };
in
{
  imports = [
    ./lib/make-disk-image.nix

    (lib.mkRemovedOptionModule [ "disko" "tests" "extraConfig" ] ''
      `disko.tests.extraConfig` has been removed. The shared-overlay role
      split into the two consumers that previously imported it:

        - For the install-test, set on `disko.test.defaults` (applies to
          every node — the test framework's native "imported into all
          nodes" hook):

            disko.test.defaults = { ... };

        - For `system.build.vmWithDisko`, set on the variant directly:

            virtualisation.vmVariantWithDisko = { imports = [ ... ]; };
    '')

    # 8 × `mkRenamedOptionModule` redirecting flat knobs into the
    # `disko.test` submodule. Existing user configs keep working with one
    # deprecation warning per renamed setter.
    (lib.mkRenamedOptionModule [ "disko" "tests" "bootCommands" ] [ "disko" "test" "bootCommands" ])
    (lib.mkRenamedOptionModule [ "disko" "tests" "efi" ] [ "disko" "test" "efi" ])
    (lib.mkRenamedOptionModule [ "disko" "tests" "extraChecks" ] [ "disko" "test" "extraChecks" ])
    (lib.mkRenamedOptionModule [ "disko" "tests" "boot" ] [ "disko" "test" "boot" ])
    (lib.mkRenamedOptionModule [ "disko" "tests" "enableCanokey" ] [ "disko" "test" "enableCanokey" ])
    (lib.mkRenamedOptionModule [ "disko" "tests" "postDisko" ] [ "disko" "test" "postDisko" ])
    (lib.mkRenamedOptionModule [ "disko" "tests" "name" ] [ "disko" "test" "name" ])
    (lib.mkRenamedOptionModule [ "disko" "tests" "enableOCR" ] [ "disko" "test" "enableOCR" ])
  ];

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

      copyNixStoreThreads = lib.mkOption {
        type = lib.types.either lib.types.ints.positive (lib.types.enum [ "auto" ]);
        description = ''
          Number of parallel threads to use when copying the nix store.
          Set to "auto" (the default) to automatically determine based on CPU cores,
          capped at 8. Higher values may hurt performance on some systems due to
          virtiofsd file descriptor limits.
        '';
        default = "auto";
        example = 4;
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

  };

  options.disko.test = lib.mkOption {
    description = ''
      The full NixOS test evaluation backing `system.build.diskoTest`
      (and its back-compat alias `system.build.installTest`).

      Override `nodes.formatter` to tweak the formatter VM (the one that
      runs disko); override `nodes.machine` to tweak the booted system.
      Override `testScript`, `enableOCR`, `defaults`, `globalTimeout`,
      etc. to reach the test framework directly. The disko-specific
      convenience knobs (`extraChecks`, `bootCommands`, `boot`, `efi`,
      `postDisko`, `enableCanokey`, `mode`) are declared on the test
      eval inside `./lib/install-test.nix` itself.

      Singular: there's one install-test today. The path is the *role*
      ("a test"); the framework's `name` option discriminates the
      *identity* (e.g. `disko.test.name = "luks-on-mdadm";`). Future
      tests, if any materialize, sit at parallel singular paths
      (`disko.formatTest`, `disko.upgradeTest`).
    '';
    inherit (installTestEval) type;
    default = { };
    visible = "shallow";
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
      makeTest = import "${modulesPath}/../tests/make-test-python.nix";
      eval-config = import "${modulesPath}/../lib/eval-config.nix";
      qemu-common = import "${modulesPath}/../lib/qemu-common.nix";
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
            bootCommands = cfg.test.bootCommands;
            efi = cfg.test.efi;
            enableOCR = cfg.test.enableOCR;
            extraTestScript = cfg.test.extraChecks;
          };

          diskoTest = lib.mkDefault config.disko.test.test;

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
