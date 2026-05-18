{
  imports = [ ../example/luks-on-mdadm.nix ];
  disko.test = {
    name = "luks-on-mdadm";
    extraChecks = ''
      machine.succeed("test -b /dev/md/raid1");
      machine.succeed("mountpoint /");
    '';
    nodes.machine.boot.loader.systemd-boot.enable = false;
  };
}
