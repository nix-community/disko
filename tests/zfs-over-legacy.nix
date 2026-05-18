{
  imports = [ ../example/zfs-over-legacy.nix ];
  disko.test = {
    name = "zfs-over-legacy";
    extraChecks = ''
      machine.succeed("test -e /zfs_fs");
      machine.succeed("mountpoint /zfs_fs");
    '';
  };
  networking.hostId = "8425e349";
}
