{
  imports = [ ../example/lvm-raid.nix ];
  disko.test = {
    name = "lvm-raid";
    extraChecks = ''
      machine.succeed("mountpoint /home");
    '';
    nodes.formatter.boot.kernelModules = [
      "dm-raid"
      "raid0"
      "dm-mirror"
    ];
    # sadly systemd-boot fails to install to a raid /boot device
    nodes.machine.boot.loader.systemd-boot.enable = false;
  };
}
