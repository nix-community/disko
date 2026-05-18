{
  imports = [ ../example/btrfs-only-root-subvolume.nix ];
  disko.test = {
    name = "btrfs-only-root-subvolume";
    extraChecks = ''
      machine.succeed("btrfs subvolume list /");
    '';
  };
}
