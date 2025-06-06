{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "btrfs-raid-mirrored-boot";
  disko-config = ../example/btrfs-raid-mirrored-boot.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
  extraSystemConfig = {
    # Mirrored boot partitions are not supported on systemd-boot.
    boot.loader.systemd-boot.enable = false;
  };
}
