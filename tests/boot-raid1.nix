{
  imports = [ ../example/boot-raid1.nix ];
  disko.test = {
    name = "boot-raid1";
    extraChecks = ''
      machine.succeed("test -b /dev/md/boot");
      machine.succeed("mountpoint /boot");
    '';
    # sadly systemd-boot fails to install to a raid /boot device
    nodes.machine.boot.loader.systemd-boot.enable = false;
  };
}
