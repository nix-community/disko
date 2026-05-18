{
  imports = [ ../example/gpt-name-with-whitespace.nix ];
  disko.test = {
    name = "gpt-name-with-whitespace";
    extraChecks = ''
      machine.succeed("mountpoint /");
      machine.succeed("mountpoint '/name with spaces'");
      machine.succeed("mountpoint '/name^with\\some@special#chars'");
    '';
  };
}
