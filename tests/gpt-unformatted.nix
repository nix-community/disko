{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "gpt-unformatted";
  disko-config = ../example/gpt-unformatted.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
}
