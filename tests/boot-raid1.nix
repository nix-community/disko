{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ../lib { }).testLib.makeDiskoTest
}:
makeDiskoTest {
  inherit pkgs;
  name = "boot-raid1";
  disko-config = ../example/boot-raid1.nix;
  extraTestScript = ''
    machine.succeed("test -b /dev/md/boot");
    machine.succeed("mountpoint /boot");
  '';
}
