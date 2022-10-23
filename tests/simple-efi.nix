{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = import ../example/simple-efi.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
}
