{
  imports = [ ../example/btrfs-subvolumes.nix ];
  disko.test = {
    name = "btrfs-subvolumes";
    extraChecks = ''
      machine.succeed("test ! -e /test");
      machine.succeed("test -e /home/user");
      machine.succeed("btrfs subvolume list / | grep -qs 'path test$'");
      machine.succeed("btrfs subvolume list / | grep -qs 'path nix$'");
      machine.succeed("btrfs subvolume list / | grep -qs 'path home$'");
      machine.succeed("test -e /.swapvol/swapfile");
      machine.succeed("test -e /.swapvol/rel-path");
      machine.succeed("test -e /partition-root/swapfile");
      machine.succeed("test -e /partition-root/swapfile1");
    '';
  };
}
