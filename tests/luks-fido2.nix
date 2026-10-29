{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "luks-fido2";
  disko-config = ../example/luks-fido2.nix;
  enableCanokey = true;
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda2");
    machine.succeed("mountpoint /");

    machine.succeed("systemd-cryptenroll /dev/vda2 | grep -qw fido2")
    # Recovery should be disabled
    machine.fail("systemd-cryptenroll /dev/vda2 | grep -qw recovery")
  '';
}
