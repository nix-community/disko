{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "luks-interactive-login";
  disko-config = ../example/luks-interactive-login.nix;
  enableOCR = true;
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda2");
  '';
  bootCommands = ''
    machine.wait_for_text("[Pp]assphrase for")
    machine.send_chars("secretsecret\n")
  '';
}
