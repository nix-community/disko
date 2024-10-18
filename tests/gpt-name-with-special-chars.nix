{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "gpt-name-with-whitespace";
  disko-config = ../example/gpt-name-with-whitespace.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("mountpoint '/name with spaces'");
    machine.succeed("mountpoint '/name^with\\some@special#chars'");
  '';
}
