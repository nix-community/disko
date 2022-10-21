{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = import ../example/with-lib.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
  efi = false;
  grub-devices = [ "/dev/vdb" ];
}
