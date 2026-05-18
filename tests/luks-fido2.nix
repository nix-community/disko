{
  imports = [ ../example/luks-fido2.nix ];
  disko.test = {
    name = "luks-fido2";
    enableCanokey = true;
    extraChecks = ''
      machine.succeed("cryptsetup isLuks /dev/vda2");
      machine.succeed("mountpoint /");
    '';
  };
}
