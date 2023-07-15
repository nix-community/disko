{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ../lib { }).testLib.makeDiskoTest
}:
makeDiskoTest {
  inherit pkgs;
  name = "lvm-raid";
  disko-config = ../example/lvm-raid.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /home");
  '';
  extraInstallerConfig = {
    boot.kernelModules = [ "dm-raid0" "dm-mirror" ];
  };
}
