{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../src/disko_lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "hybrid";
  disko-config = ../../example/hybrid.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
}
