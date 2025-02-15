{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "luks-lvm";
  disko-config = ../example/luks-lvm.nix;
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda2");
    machine.succeed("mountpoint /home");
  '';
}
