{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "luks-tpm2";
  disko-config = ../example/luks-tpm2.nix;
  enableCanokey = true;
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda2");
    machine.succeed("mountpoint /");

    machine.succeed("systemd-cryptenroll /dev/vda2 | grep -qw tpm2")
    # Recovery should be disabled
    machine.fail("systemd-cryptenroll /dev/vda2 | grep -qw recovery")
  '';
}
