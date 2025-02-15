{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "legacy-table-with-whitespace";
  disko-config = ../example/legacy-table-with-whitespace.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("mountpoint /name_with_spaces");
  '';
}
