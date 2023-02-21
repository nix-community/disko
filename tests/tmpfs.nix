{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  name = "tmpfs";
  disko-config = ../example/tmpfs.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("mountpoint /tmp");
  '';
}
