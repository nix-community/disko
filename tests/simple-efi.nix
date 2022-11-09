{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = ../example/simple-efi.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
}
