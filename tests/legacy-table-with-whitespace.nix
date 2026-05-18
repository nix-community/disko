{
  imports = [ ../example/legacy-table-with-whitespace.nix ];
  disko.test = {
    name = "legacy-table-with-whitespace";
    extraChecks = ''
      machine.succeed("mountpoint /");
      machine.succeed("mountpoint /name_with_spaces");
    '';
  };
}
