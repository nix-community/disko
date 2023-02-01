{ config, pkgs, ... }:

{
  # point root to the physical partition that your LUKS encrypted LVM volume is on
  boot.initrd.luks.devices = {
    root = {
      device = "/dev/nvme0n1p2";
      preLVM = true;
    };
  };


  # your config here
}

