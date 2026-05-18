{
  imports = [ ../example/hybrid-tmpfs-on-root.nix ];
  disko.test = {
    name = "hybrid-tmpfs-on-root";
    extraChecks = ''
      machine.succeed("mountpoint /");
      machine.succeed("findmnt / --types tmpfs");
    '';
  };
}
