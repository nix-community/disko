# this is a regression test for https://github.com/nix-community/disko/issues/52
{
  imports = [ ../example/multi-device-no-deps.nix ];
  disko.test = {
    name = "multi-device-no-deps";
    boot = false;
    extraChecks = ''
      machine.succeed("mountpoint /mnt/a");
      machine.succeed("mountpoint /mnt/b");
    '';
  };
}
