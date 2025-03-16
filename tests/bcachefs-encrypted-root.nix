{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcachefs-encrypted-root";
  disko-config = ../example/bcachefs-encrypted-root.nix;
  enableOCR = true;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
  extraInstallerConfig = {
    boot.supportedFilesystems = [ "bcachefs" ];
  };
  bootCommands = ''
    machine.wait_for_text("enter passphrase for")
    machine.send_chars("secretsecret\n")
  '';
}
