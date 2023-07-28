{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "gpt-bios-compat";
  disko-config = ../example/gpt-bios-compat.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
  efi = false;
}
