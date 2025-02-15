{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "hybrid-mbr";
  disko-config = ../example/hybrid-mbr.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
}
