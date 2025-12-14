{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "btrfs-raid1-mirrored-boot";
  disko-config = ../example/btrfs-raid1-mirrored-boot.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("mountpoint /boot0");
    machine.succeed("mountpoint /boot1");
  '';
  extraSystemConfig = {
    # Mirrored boot partitions are not supported on systemd-boot.
    boot.loader.systemd-boot.enable = false;
  };
}
