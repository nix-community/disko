# this is a regression test for https://github.com/nix-community/disko/issues/52
{
  imports = [ ../example/negative-size.nix ];
  disko.test = {
    name = "negative-size";
    boot = false;
    extraChecks = ''
      machine.succeed("mountpoint /mnt");
    '';
  };
}
