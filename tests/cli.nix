{ lib, ... }:
{
  imports = [ ../example/complex.nix ];
  disko.test = {
    name = lib.mkForce "cli";
    mode = "direct";
    extraChecks = lib.mkForce ''
      machine.succeed("test -b /dev/md/raid1p1");
      machine.succeed("mountpoint /zfs_fs");
      machine.succeed("mountpoint /zfs_legacy_fs");
      machine.succeed("mountpoint /ext4onzfs");
      machine.succeed("mountpoint /ext4_on_lvm");
    '';
    nodes.machine.fileSystems = {
      "/zfs_legacy_fs".options = [ "nofail" ];
      "/zfs_fs".options = [ "nofail" ];
    };
    nodes.formatter.boot.kernelModules = [
      "dm-raid"
      "dm-mirror"
    ];
  };
  networking.hostId = "8425e349";
}
