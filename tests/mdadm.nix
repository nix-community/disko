{
  imports = [ ../example/mdadm.nix ];
  disko.test = {
    name = "mdadm";
    efi = false;
    extraChecks = ''
      machine.succeed("test -b /dev/md/raid1");
      machine.succeed("mountpoint /");
    '';
  };
}
