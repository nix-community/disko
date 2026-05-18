{
  imports = [ ../example/mdadm-raid0.nix ];
  disko.test = {
    name = "mdadm-raid0";
    efi = false;
    extraChecks = ''
      machine.succeed("test -b /dev/md/raid0");
      machine.succeed("mountpoint /");
    '';
  };
}
