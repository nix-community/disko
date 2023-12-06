{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "lvm-raid";
  disko-config = ../example/lvm-raid.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /home");
  '';
  extraInstallerConfig = {
    boot.kernelModules = [ "dm-raid" "raid0" "dm-mirror" ];
  };
  extraSystemConfig = {
    # sadly systemd-boot fails to install to a raid /boot device
    boot.loader.systemd-boot.enable = false;
  };
}
