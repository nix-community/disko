{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "complex";
  disko-config = ../example/complex.nix;
  extraInstallerConfig.networking.hostId = "8425e349";
  extraSystemConfig = {
    networking.hostId = "8425e349";
    fileSystems."/zfs_legacy_fs".options = [ "nofail" ]; # TODO find out why we need this!
    fileSystems."/zfs_fs".options = [ "nofail" ]; # TODO find out why we need this!
  };
  extraTestScript = ''
    machine.succeed("test -b /dev/md/raid1p1");
    machine.succeed("test -b /dev/disk/by-partuuid/f0f0f0f0-f0f0-f0f0-f0f0-f0f0f0f0f0f0")

    machine.succeed("mountpoint /zfs_fs");
    machine.succeed("mountpoint /zfs_legacy_fs");
    machine.succeed("mountpoint /ext4onzfs");
    machine.succeed("mountpoint /ext4_on_lvm");


    machine.succeed("test -e /ext4_on_lvm/file-from-postMountHook");
  '';
  extraInstallerConfig = {
    boot.kernelModules = [
      "dm-raid"
      "dm-mirror"
    ];
  };
}
