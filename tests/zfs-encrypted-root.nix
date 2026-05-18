{ lib, ... }:
{
  imports = [ ../example/zfs-encrypted-root.nix ];
  disko.test = {
    name = "zfs-encrypted-root";
    defaults.disko.devices.zpool.zroot.datasets.root.options.keylocation =
      lib.mkForce "file:///tmp/secret.key";
    extraChecks = ''
      machine.succeed("mountpoint /");
      machine.succeed("mountpoint /nix");
      machine.succeed("swapon --show=NAME | grep /dev/zd"); # i.e. /dev/zd0
    '';
  };
  networking.hostId = "8425e349";
}
