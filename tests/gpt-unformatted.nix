{
  imports = [ ../example/gpt-unformatted.nix ];
  disko.test = {
    name = "gpt-unformatted";
    extraChecks = ''
      machine.succeed("mountpoint /");
    '';
  };
}
