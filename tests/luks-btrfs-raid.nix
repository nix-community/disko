{
  imports = [ ../example/luks-btrfs-raid.nix ];
  disko.test = {
    name = "luks-btrfs-raid";
    extraChecks = ''
      machine.succeed("cryptsetup isLuks /dev/vda2");
      machine.succeed("cryptsetup isLuks /dev/vdb1");
      machine.succeed("btrfs subvolume list /");
    '';
  };
}
