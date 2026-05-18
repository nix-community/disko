{
  imports = [ ../example/luks-btrfs-subvolumes.nix ];
  disko.test = {
    name = "luks-btrfs-subvolumes";
    extraChecks = ''
      machine.succeed("cryptsetup isLuks /dev/vda2");
      machine.succeed("btrfs subvolume list / | grep -qs 'path nix$'");
      machine.succeed("btrfs subvolume list / | grep -qs 'path home$'");
      machine.succeed("test -e /.swapvol/swapfile");
    '';
  };
}
