{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "boot-raid1";
  disko-config = ../example/boot-raid1.nix;
  extraTestScript = ''
    machine.succeed("test -b /dev/md/boot");
    machine.succeed("mountpoint /boot");
  '';
  extraSystemConfig = {
    # sadly systemd-boot fails to install to a raid /boot device
    boot.loader.systemd-boot.enable = false;
  };
}
