{
  imports = [ ../example/long-device-name.nix ];
  disko.test = {
    name = "long-device-name";
    extraChecks = ''
      machine.succeed("mountpoint /");
    '';
  };
}
