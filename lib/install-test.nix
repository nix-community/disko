{
  config,
  lib,
  pkgs,
  diskoLib,
  diskoDevices,
  ...
}:
{
  options = {
    bootCommands = lib.mkOption {
      description = ''
        NixOS test script commands to run after the machine has started.
        Can be used to enter an interactive password.
      '';
      type = lib.types.lines;
      default = "";
    };

    efi = lib.mkOption {
      description = ''
        Whether efi is enabled for the install-test. Defaults to true on
        architectures with OVMF firmware available (i.e. not RISC-V).
        Examples that need BIOS boot (e.g. EF02-partitioned grub setups)
        should set `efi = false;` explicitly.
      '';
      type = lib.types.bool;
      default = !pkgs.stdenv.hostPlatform.isRiscV64;
    };

    extraChecks = lib.mkOption {
      description = "Extra checks to run in the install-test.";
      type = lib.types.lines;
      default = "";
      example = ''machine.succeed("test -e /var/secrets/my.secret")'';
    };

    boot =
      lib.mkEnableOption ''
        booting the installed system after formatting/installing. Set to
        false for format-only tests
      ''
      // {
        default = true;
        example = false;
      };

    enableCanokey = lib.mkEnableOption ''
      attaching a virtual Canokey (FIDO2) device to the install-test VMs.
    '';

    postDisko = lib.mkOption {
      description = ''
        Extra shell commands to run in the formatter VM after disko
        finishes, before the closure copy and `nixos-enter`.
      '';
      type = lib.types.lines;
      default = "";
    };

    mode = lib.mkOption {
      description = ''
        How to invoke disko in the install-test:
          - "module" (default): run the disko NixOS module's
            `system.build.{format,mount,destroyFormatMount}` derivations.
            Tests the module integration path.
          - "direct": run the standalone CLI scripts built from
            `disko.devices` alone via `_cliFormat`/`_cliMount`/etc. —
            the same minimal eval the `disko` CLI uses internally. Catches
            divergence between the module-eval and standalone-eval paths.
      '';
      type = lib.types.enum [
        "module"
        "direct"
      ];
      default = "module";
    };
  };

  config =
    let
      inherit (diskoLib.testLib) prepareDiskoConfig devices;

      # The formatter VM uses /dev/vda for its own root disk;
      # disks-under-test start at /dev/vdb. The booted machine has no
      # test-runner overhead, so its disks-under-test start at /dev/vda.
      testConfigInstall = prepareDiskoConfig { disko.devices = diskoDevices; } (lib.tail devices);
      testConfigBooted = prepareDiskoConfig { disko.devices = diskoDevices; } devices;

      num-disks = builtins.length (builtins.attrNames testConfigBooted.disko.devices.disk);

      qemu-common = import (pkgs.path + "/nixos/lib/qemu-common.nix") {
        inherit lib;
        inherit (pkgs) stdenv;
      };
      qemuBinaryString = qemu-common.qemuBinary pkgs.qemu_test;

      # Standalone-eval CLI scripts for `mode = "direct"`. Built from the
      # minimal `disko.devices`-only eval — the same eval the disko CLI
      # uses internally.
      tsp-generator = pkgs.callPackage ../. { checked = true; };
      tsp-format = (tsp-generator._cliFormat testConfigInstall) pkgs;
      tsp-mount = (tsp-generator._cliMount testConfigInstall) pkgs;
      tsp-unmount = (tsp-generator._cliUnmount testConfigInstall) pkgs;
      tsp-disko = (tsp-generator._cliDestroyFormatMount testConfigInstall) pkgs;
    in
    {
      name = lib.mkDefault "${config.nodes.machine.networking.hostName or "machine"}-installTest";

      globalTimeout = 600;
      meta.timeout = 600;

      nodes.formatter =
        { lib, ... }:
        {
          imports = [
            ./install-test-formatter.nix
          ]
          ++ lib.optionals (config.mode == "module") [
            ../module.nix
            {
              disko = {
                enableConfig = false;
                checkScripts = true;
                # `lib.mkOverride 70` sits between user
                # `disko.test.defaults.*` overrides at `lib.mkForce` (50,
                # which wins for per-leaf test-time overrides like LUKS
                # `passwordFile` or ZFS `keylocation`) and regular
                # assignments at priority 100 (which would compete with
                # the host example's `disko.devices` at the same priority,
                # list-concatenating legacy-table partitions).
                devices = lib.mkOverride 70 testConfigInstall.disko.devices;
              };
            }
          ];

          # `networking.hostId` is propagated to every node via
          # `defaults.networking.hostId` in module.nix's evalTest call
          # (sourced from the host eval's config). No per-node setter
          # needed here.
          virtualisation = {
            emptyDiskImages = builtins.genList (_: 4096) num-disks;
            qemu.options = lib.mkIf config.enableCanokey [
              "-device pci-ohci,id=usb-bus"
              "-device canokey,bus=usb-bus.0,file=/tmp/canokey-file"
            ];
          };
        };

      nodes.machine =
        { lib, ... }:
        {
          imports = [ ./install-test-machine.nix ];
          disko.devices = lib.mkOverride 70 testConfigBooted.disko.devices;

          # The test framework imports `nixos/lib/testing/nixos-test-base.nix`
          # into every node, which pulls in `qemu-vm.nix`. qemu-vm.nix sets
          # `fileSystems = lib.mkIf (cfg.fileSystems != { }) (mkVMOverride
          # cfg.fileSystems);` (mkVMOverride = priority 10) — wiping out
          # disko's fileSystems with test-VM defaults (`tmpfs /`, 9p
          # `/nix/store`, etc.). The installed system would then have wrong
          # `/etc/fstab` and fail to boot from the disko-formatted disk.
          # Clearing `virtualisation.fileSystems` makes the mkIf fire false,
          # letting disko's fileSystems through.
          virtualisation.fileSystems = lib.mkForce { };

          # Bootloader config sourced from `config.efi` (the test-eval-level
          # option). `install-test-machine.nix` deliberately doesn't read
          # `disko.test.efi` from the machine eval — that would be circular
          # since the machine eval doesn't declare `disko.test` at all.
          boot.loader.grub.efiInstallAsRemovable = config.efi;
          boot.loader.grub.efiSupport = config.efi;
          boot.loader.systemd-boot.enable = lib.mkDefault config.efi;
          boot.loader.grub.devices = lib.mkOverride 70 testConfigInstall.boot.loader.grub.devices;
        };

      testScript =
        { nodes, ... }:
        ''
          import shlex

          def disks(oldmachine, num_disks):
              disk_flags = []
              for i in range(num_disks):
                  disk_flags += [
                    '-drive',
                    f"file={oldmachine.state_dir}/empty{i}.qcow2,id=drive{i + 1},if=none,index={i + 1},werror=report",
                    '-device',
                    f"virtio-blk-pci,drive=drive{i + 1}"
                  ]
              return disk_flags

          def create_test_machine(oldmachine=None, **kwargs):
              start_command = shlex.split("${qemuBinaryString}") + [
                  "-m", "1024",
                  "-virtfs", "local,path=/nix/store,security_model=none,mount_tag=nix-store",
                  *disks(oldmachine, ${toString num-disks})
              ]
              ${lib.optionalString config.efi ''
                start_command += [
                  "-drive", "if=pflash,format=raw,unit=0,readonly=on,file=${pkgs.OVMF.firmware}",
                  "-drive", "if=pflash,format=raw,unit=1,readonly=on,file=${pkgs.OVMF.variables}"
                ]
              ''}
              ${lib.optionalString config.enableCanokey ''
                start_command += [
                  "-device", "pci-ohci,id=usb-bus",
                  "-device", "canokey,bus=usb-bus.0,file=/tmp/canokey-file"
                ]
              ''}
              machine = create_machine(start_command=" ".join(start_command), **kwargs)
              driver.machines.append(machine)
              return machine

          formatter.start()
          formatter.succeed("echo -n 'additionalSecret' > /tmp/additionalSecret.key")
          formatter.succeed("echo -n 'secretsecret' > /tmp/secret.key")

          ${lib.optionalString (config.mode == "direct") ''
            formatter.succeed("${lib.getExe tsp-format}")
            formatter.succeed("${lib.getExe tsp-mount}")
            formatter.succeed("${lib.getExe tsp-mount}")  # idempotent
            formatter.succeed("${lib.getExe tsp-unmount}")
            formatter.succeed("${lib.getExe tsp-unmount}")  # idempotent
            formatter.succeed("${lib.getExe tsp-mount}")  # idempotent
            formatter.succeed("${lib.getExe tsp-disko} --yes-wipe-all-disks")
            formatter.succeed("mkdir -p /mnt/home")
            formatter.succeed("touch /mnt/home/testfile")
            formatter.succeed("${lib.getExe tsp-format}")  # idempotent
            formatter.succeed("test -e /mnt/home/testfile")
          ''}
          ${lib.optionalString (config.mode == "module") ''
            formatter.succeed("${lib.getExe nodes.formatter.system.build.format}")
            formatter.succeed("${lib.getExe nodes.formatter.system.build.mount}")
            formatter.succeed("${lib.getExe nodes.formatter.system.build.mount}")  # idempotent
            formatter.succeed("${lib.getExe nodes.formatter.system.build.unmount}")
            formatter.succeed("${lib.getExe nodes.formatter.system.build.unmount}")  # idempotent
            formatter.succeed("${lib.getExe nodes.formatter.system.build.mount}")  # idempotent
            formatter.succeed("${lib.getExe nodes.formatter.system.build.destroyFormatMount} --yes-wipe-all-disks")
            formatter.succeed("mkdir -p /mnt/home")
            formatter.succeed("touch /mnt/home/testfile")
            formatter.succeed("${lib.getExe nodes.formatter.system.build.format}")  # idempotent
            formatter.succeed("test -e /mnt/home/testfile")
          ''}

          ${config.postDisko}

          ${lib.optionalString config.boot ''
            # mount nix-store in /mnt
            formatter.succeed("mkdir -p /mnt/nix/store")
            formatter.succeed("mount --bind /nix/store /mnt/nix/store")
            formatter.succeed("nix-store --load-db < ${
              pkgs.closureInfo { rootPaths = [ nodes.machine.system.build.toplevel ]; }
            }/registration")
            formatter.succeed("mkdir -p /mnt/etc")
            formatter.succeed("touch /mnt/etc/NIXOS")
            formatter.succeed("mkdir -p /mnt/nix/var/nix/profiles")
            formatter.succeed("nix-env -p /mnt/nix/var/nix/profiles/system --set ${nodes.machine.system.build.toplevel}")
            formatter.succeed("NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root /mnt -- ${nodes.machine.system.build.toplevel}/bin/switch-to-configuration boot")
            formatter.succeed("sync")
            formatter.shutdown()

            machine = create_test_machine(oldmachine=formatter, name="booted_machine")
            machine.start()
            ${config.bootCommands}
            machine.wait_for_unit("local-fs.target")
          ''}

          ${config.extraChecks}
        '';
    };
}
