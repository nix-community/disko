{
  imports = [ ../example/legacy-table.nix ];
  disko.test = {
    name = "legacy-table";
    extraChecks = ''
      machine.succeed("mountpoint /");
    '';
  };
}
