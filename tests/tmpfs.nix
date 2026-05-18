{
  imports = [ ../example/tmpfs.nix ];
  disko.test = {
    name = "tmpfs";
    extraChecks = ''
      machine.succeed("mountpoint /");
      machine.succeed("mountpoint /tmp");
    '';
  };
}
