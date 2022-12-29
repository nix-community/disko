{ pkgs ? (import <nixpkgs> { })
, makeTest ? import <nixpkgs/nixos/tests/make-test-python.nix>
, eval-config ? import <nixpkgs/nixos/lib/eval-config.nix>
, ...
}:
{
  makeDiskoTest =
    { disko-config
    , extraTestScript ? ""
    , bootCommands ? ""
    , extraConfig ? { }
    , efi ? true
    , enableOCR ? false
    , postDisko ? ""
    , testMode ? "direct" # can be one of direct module cli
    , testBoot ? true # if we actually want to test booting or just create/mount
    }:
    let
      lib = pkgs.lib;
      makeTest' = args:
        makeTest args {
          inherit pkgs;
          inherit (pkgs) system;
        };
      disks = [ "/dev/vda" "/dev/vdb" "/dev/vdc" "/dev/vdd" "/dev/vde" "/dev/vdf" ];
      tsp-create = pkgs.writeScript "create" ((pkgs.callPackage ../. { }).create (import disko-config { disks = builtins.tail disks; inherit lib; }));
      tsp-mount = pkgs.writeScript "mount" ((pkgs.callPackage ../. { }).mount (import disko-config { disks = builtins.tail disks; inherit lib; }));
      tsp-config = (pkgs.callPackage ../. { }).config (import disko-config { inherit disks; inherit lib; });
      tsp-disko = pkgs.writeScript "disko" ((pkgs.callPackage ../. { }).zapCreateMount (import disko-config { disks = builtins.tail disks; inherit lib; }));
      num-disks = builtins.length (lib.attrNames (import disko-config { inherit lib; }).disk);
      installed-system = { modulesPath, ... }: {
        imports = [
          (lib.optionalAttrs (testMode == "direct" || testMode == "cli") tsp-config)
          (lib.optionalAttrs (testMode == "module") {
            imports = [ ../module.nix ];
            disko = {
              enableConfig = true;
              devices = import disko-config { inherit disks lib; };
            };
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
        boot.kernelParams = lib.mkAfter [ "console=tty0" ]; # needed to have serial interaction during boot
        boot.zfs.devNodes = "/dev/disk/by-uuid"; # needed because /dev/disk/by-id is empty in qemu-vms

        boot.consoleLogLevel = lib.mkForce 100;
        boot.loader.grub = {
          efiSupport = efi;
          efiInstallAsRemovable = efi;
        };
      };
      installedTopLevel = (eval-config {
        modules = [ installed-system ];
        inherit (pkgs) system;
      }).config.system.build.toplevel;
    in
    makeTest' {
      name = "disko";

      inherit enableOCR;
      nodes.machine = { config, pkgs, modulesPath, ... }: {
        imports = [
          (lib.optionalAttrs (testMode == "module") {
            imports = [ ../module.nix ];
            disko = {
              enableConfig = false;
              devices = import disko-config { disks = builtins.tail disks; inherit lib; };
            };
          })
          (lib.optionalAttrs (testMode == "cli") {
            imports = [ (modulesPath + "/installer/cd-dvd/channel.nix") ];
            system.extraDependencies = [
              ((pkgs.callPackage ../. { }).createScript (import disko-config { disks = builtins.tail disks; inherit lib; }) pkgs)
              ((pkgs.callPackage ../. { }).mountScript (import disko-config { disks = builtins.tail disks; inherit lib; }) pkgs)
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
          substituters = lib.mkForce [];
          hashed-mirrors = null;
          connect-timeout = 1;
        };

        virtualisation.emptyDiskImages = builtins.genList (_: 4096) num-disks;
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
          machine.succeed("${nodes.machine.system.build.disko}") # verify that we can destroy and recreate again
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
}
