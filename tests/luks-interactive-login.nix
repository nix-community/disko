{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest (let
  disko-config = import ../example/luks-interactive-login.nix;
in {
  inherit pkgs;
  name = "luks-interactive-login";
  inherit disko-config;
  inherit (disko-config.disko.tests) extraDiskoConfig;
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda2");
  '';
  bootCommands = ''
    machine.wait_for_console_text("vda")
    machine.send_console("secretsecret\n")
  '';
})
