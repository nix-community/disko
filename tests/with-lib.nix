{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  name = "with-lib";
  disko-config = ../example/with-lib.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
  efi = false;
  grub-devices = [ "/dev/vdb" ];
}
