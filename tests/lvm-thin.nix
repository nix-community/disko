{
  imports = [ ../example/lvm-thin.nix ];
  disko.test = {
    name = "lvm-thin";
    extraChecks = ''
      machine.succeed("mountpoint /home");
    '';
  };
}
