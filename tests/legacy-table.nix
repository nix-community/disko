{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ../lib { }).testLib.makeDiskoTest
}:
makeDiskoTest {
  inherit pkgs;
  name = "legacy-table";
  disko-config = ../example/legacy-table.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
}
