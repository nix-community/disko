{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "legacy-table";
  disko-config = ../example/legacy-table.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
}
