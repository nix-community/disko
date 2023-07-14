{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ../lib { }).testLib.makeDiskoTest
}:
makeDiskoTest {
  inherit pkgs;
  name = "gpt-bios-compat";
  disko-config = ../example/gpt-bios-compat.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
  efi = false;
  grub-devices = [ "/dev/vdb" ];
}
