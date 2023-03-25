{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  name = "luks-lvm";
  disko-config = ../example/luks-lvm.nix;
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda2");
    machine.succeed("mountpoint /home");
  '';
  bootCommands = ''
    machine.wait_for_console_text("vda")
    machine.send_console("secretsecret\n")
  '';
}
