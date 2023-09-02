{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "zfs-over-legacy";
  extraInstallerConfig.networking.hostId = "8425e349";
  extraSystemConfig.networking.hostId = "8425e349";
  disko-config = ../example/zfs-over-legacy.nix;
  extraTestScript = ''
    machine.succeed("test -e /zfs_fs");
    machine.succeed("mountpoint /zfs_fs");
  '';
}

