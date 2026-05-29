{
  pkgs ? import <nixpkgs> { },
}:
pkgs.testers.runNixOSTest {
  name = "disko-unattended-install-module-test";
  nodes.main = ./unattended-installer.nix;

  testScript = ''
    main.start(allow_reboot=True)
    assert main.succeed("hostname").rstrip() == "unattended-installer"
    # This verifies that unattendedInstallAtBoot.service did indeed start at
    # boot and that it finished successfully.
    assert main.fail("systemctl is-failed unattendedInstallAtBoot.service").rstrip() == "inactive"
    # This makes it so that we will boot into the new installation of NixOS
    # instead of the original one when we reboot.
    main.succeed("rm --recursive --force /boot/EFI")
    main.reboot()
    assert main.succeed("hostname").rstrip() == "deployee"
  '';
}
