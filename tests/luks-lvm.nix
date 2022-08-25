{ pkgs ? (import <nixpkgs> {})
, makeDiskoTest ? (pkgs.callPackage ./lib.nix {}).makeDiskoTest
}:
makeDiskoTest {
  disko-config = import ../example/luks-lvm.nix;
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vdb2");
    machine.succeed("grep -qs '/mnt/home' /proc/mounts");
  '';
}
