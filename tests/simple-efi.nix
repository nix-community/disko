{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ../lib { }).testLib.makeDiskoTest
}:
makeDiskoTest {
  inherit pkgs;
  name = "simple-efi";
  disko-config = ../example/simple-efi.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
}
