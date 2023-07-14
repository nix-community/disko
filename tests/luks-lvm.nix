{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ../lib { }).testLib.makeDiskoTest
}:
makeDiskoTest {
  inherit pkgs;
  name = "luks-lvm";
  disko-config = ../example/luks-lvm.nix;
  extraConfig.boot.initrd.luks.devices.crypted.preLVM = false;
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda2");
    machine.succeed("mountpoint /home");
  '';
}
