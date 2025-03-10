{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "zfs-encrypted-root";
  extraInstallerConfig.networking.hostId = "8425e349";
  extraSystemConfig.networking.hostId = "8425e349";
  disko-config = pkgs.lib.recursiveUpdate (import ../example/zfs-encrypted-root.nix) {
    disko.devices.zpool.zroot.datasets.root.options.keylocation = "file:///tmp/secret.key";
  };
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("mountpoint /nix");
    machine.succeed("swapon --show=NAME | grep /dev/zd"); # i.e. /dev/zd0
  '';
}
