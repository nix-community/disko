{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "luks-fido2";
  disko-config = ../example/luks-fido2.nix;
  # This simulates a FIDO2 stick.
  enableCanokey = true;
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda2");
  '';
}
