{ lib, ... }:
{
  imports = [ ../example/complex.nix ];
  disko.test = {
    name = lib.mkForce "module";
    mode = "module";
    extraChecks = lib.mkForce ''
      machine.succeed("test -b /dev/md/raid1p1");
      machine.succeed("mountpoint /zfs_fs");
      machine.succeed("mountpoint /zfs_legacy_fs");
      machine.succeed("mountpoint /ext4onzfs");
      machine.succeed("mountpoint /ext4_on_lvm");
    '';
  };
}
