{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = import ../example/lvm-raid.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /mnt/home");
  '';
  extraConfig = {
    boot.kernelModules = [ "dm-raid" "dm-mirror" ];
  };
}
