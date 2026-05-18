{
  imports = [ ../example/hybrid-mbr.nix ];
  disko.test = {
    name = "hybrid-mbr";
    extraChecks = ''
      machine.succeed("mountpoint /");
    '';
  };
}
