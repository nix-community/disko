{
  imports = [ ../example/with-lib.nix ];
  _module.args.disks = [ "/dev/vdb" ];
  disko.test = {
    name = "with-lib";
    efi = false;
    extraChecks = ''
      machine.succeed("mountpoint /");
    '';
  };
}
