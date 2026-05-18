{
  imports = [ ../example/mdadm-raid5-args.nix ];
  disko.test = {
    name = "mdadm-raid5-args";
    efi = false;
    extraChecks = ''
      machine.succeed("test -b /dev/md/raid5");
      machine.succeed("mountpoint /");
    '';
  };
}
