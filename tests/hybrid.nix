{
  imports = [ ../example/hybrid.nix ];
  disko.test = {
    name = "hybrid";
    extraChecks = ''
      machine.succeed("mountpoint /");
    '';
  };
}
