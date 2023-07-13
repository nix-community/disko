{ pkgs ? (import <nixpkgs> { })
, lib ? pkgs.lib
, makeTest ? import <nixpkgs/nixos/tests/make-test-python.nix>
, eval-config ? import <nixpkgs/nixos/lib/eval-config.nix>
, ...
}:

let
  diskoLib = import ../lib { inherit pkgs lib; };
  testlib = {
    # this takes a disko toplevel config and changes the disk devices so we can run them inside the qemu test runner
    # basically changes all the disk.*.devices to something like /dev/vda or /dev/vdb etc.
    prepareDiskoConfig = toplevel: devices:
    let
      preparedDisks = lib.foldlAttrs (acc: n: v: {
        devices = lib.tail acc.devices;
        value = acc.value // {
          ${n} = v // {
            device = lib.head acc.devices;
          };
        };
      }) {
        inherit devices;
        value = {};
      } toplevel.disko.devices.disk;
    in
      toplevel // {
        disko.devices = toplevel.disko.devices // {
          disk = preparedDisks.value;
        };
      };

    # This is the test generator for a disko test
    makeDiskoTest =
      { name
      , disko-config
      , extraTestScript ? ""
      , bootCommands ? ""
      , extraConfig ? { }
      , grub-devices ? [ "nodev" ]
      , efi ? true
      , postDisko ? ""
      , testMode ? "module" # can be one of direct module cli
      , testBoot ? true # if we actually want to test booting or just create/mount
      }:
      let
        makeTest' = args:
          makeTest args {
            inherit pkgs;
            inherit (pkgs) system;
          };
        devices = [ "/dev/vda" "/dev/vdb" "/dev/vdc" "/dev/vdd" "/dev/vde" "/dev/vdf"];
        # for installation we skip /dev/vda because it is the test runner disk
        testConfigInstall = testlib.prepareDiskoConfig (import disko-config { inherit lib; }) (lib.tail devices);
        # we need to shift the disks by one because the first disk is the /dev/vda of the test runner
        # so /dev/vdb becomes /dev/vda etc.
        testConfigBooted = testlib.prepareDiskoConfig (import disko-config { inherit lib; }) devices;

        tsp-generator = pkgs.callPackage ../. { checked = true; };
        tsp-create = (tsp-generator.createScript testConfigInstall) pkgs;
        tsp-mount = (tsp-generator.mountScript testConfigInstall) pkgs;
        tsp-disko = (tsp-generator.diskoScript testConfigInstall) pkgs;
        tsp-config = tsp-generator.config testConfigBooted;
        num-disks = builtins.length (lib.attrNames testConfigBooted.disko.devices.disk);
        installed-system = { modulesPath, ... }: {
          imports = [
            (lib.optionalAttrs (testMode == "direct" || testMode == "cli") tsp-config)
            (lib.optionalAttrs (testMode == "module") {
              disko.enableConfig = true;
              imports = [
                ../module.nix
                testConfigBooted
              ];
            })
            (modulesPath + "/testing/test-instrumentation.nix")
            (modulesPath + "/profiles/qemu-guest.nix")
            (modulesPath + "/profiles/minimal.nix")
            extraConfig
          ];
          fileSystems."/nix/store" = {
            device = "nix-store";
            fsType = "9p";
            neededForBoot = true;
            options = [ "trans=virtio" "version=9p2000.L" "cache=loose" ];
          };
          documentation.enable = false;
          hardware.enableAllFirmware = lib.mkForce false;
          networking.hostId = "8425e349"; # from profiles/base.nix, needed for zfs
          boot.zfs.devNodes = "/dev/disk/by-uuid"; # needed because /dev/disk/by-id is empty in qemu-vms
          boot.initrd.preDeviceCommands = ''
            echo -n 'secretsecret' > /tmp/secret.key
          '';

          boot.consoleLogLevel = lib.mkForce 100;
          boot.loader.grub = {
            devices = grub-devices;
            efiSupport = efi;
            efiInstallAsRemovable = efi;
          };
        };
        installed-system-eval = eval-config {
          modules = [ installed-system ];
          inherit (pkgs) system;
        };

        installedTopLevel = installed-system-eval.config.system.build.toplevel;
      in
      makeTest' {
        name = "disko-${name}";

        nodes.machine = { pkgs, modulesPath, ... }: {
          imports = [
            (lib.optionalAttrs (testMode == "module") {
              imports = [
                ../module.nix
              ];
              disko = {
                enableConfig = false;
                checkScripts = true;
                devices = testConfigInstall.disko.devices;
              };
            })
            (lib.optionalAttrs (testMode == "cli") {
              imports = [ (modulesPath + "/installer/cd-dvd/channel.nix") ];
              system.extraDependencies = [
                ((pkgs.callPackage ../. { checked = true; }).createScript testConfigInstall pkgs)
                ((pkgs.callPackage ../. { checked = true; }).mountScript testConfigInstall pkgs)
              ];
            })
            (modulesPath + "/profiles/base.nix")
            (modulesPath + "/profiles/minimal.nix")
            extraConfig
          ];
          environment.systemPackages = [
            pkgs.jq
          ];

          # speed-up eval
          documentation.enable = false;

          nix.settings = {
            substituters = lib.mkForce [ ];
            hashed-mirrors = null;
            connect-timeout = 1;
          };

          virtualisation.emptyDiskImages = builtins.genList (_: 4096) num-disks;

          # useful for debugging via repl
          system.build.systemToInstall = installed-system-eval;
        };

        testScript = { nodes, ... }: ''
          def disks(oldmachine, num_disks):
              disk_flags = ""
              for i in range(num_disks):
                  disk_flags += f' -drive file={oldmachine.state_dir}/empty{i}.qcow2,id=drive{i + 1},if=none,index={i + 1},werror=report'
                  disk_flags += f' -device virtio-blk-pci,drive=drive{i + 1}'
              return disk_flags
          def create_test_machine(oldmachine=None, args={}): # taken from <nixpkgs/nixos/tests/installer.nix>
              machine = create_machine({
                "qemuFlags": "-cpu max -m 1024 -virtfs local,path=/nix/store,security_model=none,mount_tag=nix-store" + disks(oldmachine, ${toString num-disks}),
                ${lib.optionalString efi ''"bios": "${pkgs.OVMF.fd}/FV/OVMF.fd",''}
              } | args)
              driver.machines.append(machine)
              return machine

          machine.start()
          machine.succeed("echo -n 'additionalSecret' > /tmp/additionalSecret.key")
          machine.succeed("echo -n 'secretsecret' > /tmp/secret.key")
          ${lib.optionalString (testMode == "direct") ''
            machine.succeed("${tsp-create}")
            machine.succeed("${tsp-mount}")
            machine.succeed("${tsp-mount}") # verify that the command is idempotent
            machine.succeed("${tsp-disko}") # verify that we can destroy and recreate
          ''}
          ${lib.optionalString (testMode == "module") ''
            machine.succeed("${nodes.machine.system.build.formatScript}")
            machine.succeed("${nodes.machine.system.build.mountScript}")
            machine.succeed("${nodes.machine.system.build.mountScript}") # verify that the command is idempotent
            machine.succeed("${nodes.machine.system.build.diskoScript}") # verify that we can destroy and recreate again
          ''}
          ${lib.optionalString (testMode == "cli") ''
            # TODO use the disko cli here
            # machine.succeed("${../.}/disko --no-pkgs --mode create ${disko-config}")
            # machine.succeed("${../.}/disko --no-pkgs --mode mount ${disko-config}")
            # machine.succeed("${../.}/disko --no-pkgs --mode mount ${disko-config}") # verify that the command is idempotent
            # machine.succeed("${../.}/disko --no-pkgs --mode zap_create_mount ${disko-config}") # verify that we can destroy and recreate again
            machine.succeed("${tsp-create}")
            machine.succeed("${tsp-mount}")
            machine.succeed("${tsp-mount}") # verify that the command is idempotent
            machine.succeed("${tsp-disko}") # verify that we can destroy and recreate
          ''}

          ${postDisko}

          ${lib.optionalString testBoot ''
            # mount nix-store in /mnt
            machine.succeed("mkdir -p /mnt/nix/store")
            machine.succeed("mount --bind /nix/store /mnt/nix/store")

            machine.succeed("nix-store --load-db < ${pkgs.closureInfo {rootPaths = [installedTopLevel];}}/registration")

            # fix "this is not a NixOS installation"
            machine.succeed("mkdir -p /mnt/etc")
            machine.succeed("touch /mnt/etc/NIXOS")

            machine.succeed("mkdir -p /mnt/nix/var/nix/profiles")
            machine.succeed("nix-env -p /mnt/nix/var/nix/profiles/system --set ${installedTopLevel}")
            machine.succeed("NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root /mnt -- ${installedTopLevel}/bin/switch-to-configuration boot")
            machine.succeed("sync")
            machine.shutdown()

            machine = create_test_machine(oldmachine=machine, args={ "name": "booted_machine" })
            machine.start()
            ${bootCommands}
            machine.wait_for_unit("local-fs.target")
          ''}

          ${extraTestScript}
        '';
      };
  };
in testlib

