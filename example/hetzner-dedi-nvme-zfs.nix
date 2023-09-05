# disko config for Hetzner Online (dedicated)
# Developed and tested on AX41-NVMe (legacy BIOS) in August 2023.

# Matching grub config:
#
# boot.initrd.availableKernelModules = [ "nvme" ];
# boot.loader.grub = {
#   devices = [ "/dev/nvme0n1" "/dev/nvme1n1" ];
#   efiSupport = true;
#   efiInstallAsRemovable = true;
# };
# fileSystems."/" = {
#   device = "tank/root";
#   fsType = "zfs";
#   neededForBoot = true;
# };
#
# Migrate your network config from the rescue system.
#
# Some settings might be not optimal or superfluous.

{ lib, disks ? [ "/dev/nvme0n1" "/dev/nvme1n1" ], ... }: {
  disk = lib.genAttrs disks (dev: {
    device = dev;
    type = "disk";
    content = {
      type = "table";
      format = "gpt";
      partitions = [
        {
          name = "boot";
          start = "0";
          end = "1MiB";
          part-type = "primary";
          flags = ["bios_grub"];
        }
        {
          name = "ESP";
          start = "1MiB";
          end = "385MiB";
          bootable = true;
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = if dev == "/dev/nvme0n1" then "/boot" else null;
          };
        }
        {
          name = "tank";
          start = "385MiB";
          end = "100%";
          content = {
            type = "zfs";
            pool = "tank";
          };
        }
      ];
    };
  });
  zpool = {
    tank = {
      type = "zpool";
      mode = "mirror";
      options = {
        ashift = "12";
        autotrim = "on";
      };
      rootFsOptions = {
        mountpoint = "none";
        acltype = "posixacl";
        canmount = "off";
        compression = "zstd";
        dnodesize = "auto";
        normalization = "formD";
        relatime = "on";
        xattr = "sa";
      };

      datasets = {
        root = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
          mountpoint = "/";
        };
      };
    };
  };
}
