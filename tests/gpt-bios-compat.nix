{
  imports = [ ../example/gpt-bios-compat.nix ];
  disko.test = {
    name = "gpt-bios-compat";
    efi = false;
    extraChecks = ''
      machine.succeed("mountpoint /");
    '';
  };
}
