{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = ../example/lvm-raid.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /home");
  '';
  extraConfig = {
    boot.kernelModules = [ "dm-raid0" "dm-mirror" ];
  };
}
