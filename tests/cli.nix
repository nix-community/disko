{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "cli";
  disko-config = ../example/complex.nix;
  extraInstallerConfig.networking.hostId = "8425e349";
  extraSystemConfig = {
    networking.hostId = "8425e349";
    fileSystems."/zfs_legacy_fs".options = [ "nofail" ]; # TODO find out why we need this!
    fileSystems."/zfs_fs".options = [ "nofail" ]; # TODO find out why we need this!
  };
  testMode = "direct";
  extraTestScript = ''
    machine.succeed("test -b /dev/md/raid1p1");

    machine.succeed("mountpoint /zfs_fs");
    machine.succeed("mountpoint /zfs_legacy_fs");
    machine.succeed("mountpoint /ext4onzfs");
    machine.succeed("mountpoint /ext4_on_lvm");
  '';
  extraSystemConfig = {
    imports = [
      ../module.nix
    ];
  };
  extraInstallerConfig = {
    boot.kernelModules = [ "dm-raid" "dm-mirror" ];
    imports = [
      ../module.nix
    ];
  };
}
