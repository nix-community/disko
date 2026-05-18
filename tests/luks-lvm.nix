{
  imports = [ ../example/luks-lvm.nix ];
  disko.test = {
    name = "luks-lvm";
    extraChecks = ''
      machine.succeed("cryptsetup isLuks /dev/vda2");
      machine.succeed("mountpoint /home");
    '';
  };
}
