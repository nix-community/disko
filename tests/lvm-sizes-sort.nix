{
  imports = [ ../example/lvm-sizes-sort.nix ];
  disko.test = {
    name = "lvm-sizes-sort";
    extraChecks = ''
      machine.succeed("mountpoint /home");
    '';
  };
}
