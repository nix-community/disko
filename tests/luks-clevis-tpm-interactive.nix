{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "luks-clevis-tpm-interactive";
  disko-config = ../example/luks-clevis-tpm-interactive.nix;
  extraInstallerConfig = {
    # TODO: figure out how to enable also in booted_machine to test TPM unlock
    virtualisation.tpm.enable = true;
  };
  extraSystemConfig = {
    # nixos/clevis does not support luks bind in non-systemd initrd
    boot.initrd.systemd.enable = true;
  };
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda2")
    machine.fail('cryptsetup open --test-passphrase /dev/vda2 --key-file <(echo -n "clevis-temp-passphrase")')
  '';
  bootCommands = ''
    machine.wait_for_console_text("A TPM2 device with the in-kernel resource manager is needed!")
    machine.wait_for_console_text("Starting password query on")
    machine.send_console("secretsecret\n")
  '';
}
