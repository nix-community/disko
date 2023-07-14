{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ../lib { }).testLib.makeDiskoTest
}:
makeDiskoTest {
  inherit pkgs;
  name = "tmpfs";
  disko-config = ../example/tmpfs.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("mountpoint /tmp");
  '';
}
