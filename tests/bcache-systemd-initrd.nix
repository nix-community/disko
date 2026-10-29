{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcache-systemd-initrd";
  disko-config = ../example/bcache.nix;
  extraInstallerConfig = {
    boot.kernelModules = [ "bcache" ];
  };
  # Boots / on bcache through the systemd initrd (the scripted initrd is
  # covered by the `bcache` test).
  extraSystemConfig = {
    boot.initrd.systemd.enable = true;
  };
  extraTestScript = ''
    machine.succeed("journalctl -b -o cat | grep -q initrd-switch-root")
    machine.succeed("findmnt -n -o SOURCE / | grep -qx /dev/bcache0")
    machine.succeed("test -e /sys/block/bcache0/bcache/cache")
    machine.succeed("grep -qF '[writeback]' /sys/block/bcache0/bcache/cache_mode")
  '';
  efi = false;
}
