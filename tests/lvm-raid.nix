{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = import ../example/lvm-raid.nix;
  extraTestScript = ''
    machine.succeed("grep -qs '/mnt/home' /proc/mounts");
  '';
  extraConfig = {
    boot.kernelModules = [ "dm-raid" "dm-mirror" ];
  };
}
