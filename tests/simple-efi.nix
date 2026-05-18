{
  imports = [ ../example/simple-efi.nix ];
  disko.test = {
    name = "simple-efi";
    extraChecks = ''
      machine.succeed("mountpoint /");
    '';
  };
}
