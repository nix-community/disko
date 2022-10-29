{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = ../example/boot-raid1.nix;
  extraTestScript = ''
    machine.succeed("test -b /dev/md/boot");
    machine.succeed("mountpoint /boot");
  '';
}
