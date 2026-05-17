{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ../module.nix ];

  documentation.enable = false;
  hardware.enableAllFirmware = lib.mkForce false;

  # FIXME: we don't have a systemd in stage-1 equivalent for this
  boot.initrd.preDeviceCommands = lib.mkIf (!config.boot.initrd.systemd.enable) ''
    echo -n 'secretsecret' > /tmp/secret.key
  '';
  boot.consoleLogLevel = lib.mkForce 100;

  boot.loader.systemd-boot.graceful = true;

  # we always want the bind-mounted nix store. otherwise tests take forever
  fileSystems."/nix/store" = lib.mkForce {
    device = "nix-store";
    fsType = "9p";
    neededForBoot = true;
    options = [
      "trans=virtio"
      "version=9p2000.L"
      "cache=loose"
    ];
  };
  boot.zfs.devNodes = "/dev/disk/by-uuid"; # needed because /dev/disk/by-id is empty in qemu-vms

  # Silence mdadm warning about missing MAILADDR or PROGRAM
  boot.swraid.mdadmConf = "PROGRAM ${pkgs.coreutils}/bin/true";

  assertions = [
    {
      assertion =
        builtins.length config.boot.loader.grub.mirroredBoots > 1 -> config.boot.loader.grub.devices == [ ];
      message = ''
        When using `--vm-test` in combination with `mirroredBoots`,
        it is necessary to configure `boot.loader.grub.devices` as an empty list by setting `boot.loader.grub.devices = lib.mkForce [];`.
        This adjustment is crucial because the `--vm-test` mechanism automatically overrides the grub boot devices as part of the virtual machine test.
      '';
    }
  ];
}
