{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "luks-on-mdadm";
  disko-config = ../example/luks-on-mdadm.nix;
  extraTestScript = ''
    machine.succeed("test -b /dev/md/raid1");
    machine.succeed("mountpoint /");
  '';
  extraSystemConfig = {
    # sadly systemd-boot fails to install to a raid /boot device
    boot.loader.systemd-boot.enable = false;
  };
}
