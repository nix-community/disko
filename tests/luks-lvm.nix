{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = ../example/luks-lvm.nix;
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda2");
    machine.succeed("mountpoint /home");
  '';
  enableOCR = true;
  bootCommands = ''
    machine.wait_for_text("Passphrase for")
    machine.send_chars("secretsecret\n")
  '';
}
