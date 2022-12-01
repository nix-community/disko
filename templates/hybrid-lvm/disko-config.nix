# Example to create a bios compatible gpt partition
{ lib, disks ? [ "/dev/sda" ], ... }: {
  disk = lib.genAttrs disks (dev: {
    device = dev;
    type = "disk";
    content = {
      type = "table";
      format = "gpt";
      partitions = [
        {
          name = "boot";
          type = "partition";
          start = "0";
          end = "1M";
          part-type = "primary";
          flags = ["bios_grub"];
        }
        {
          type = "partition";
          name = "ESP";
          start = "1MiB";
          end = "100MiB";
          bootable = true;
          content = {
            type = "mdraid";
            name = "boot";
          };
        }
        {
          name = "root";
          type = "partition";
          start = "100MiB";
          end = "100%";
          part-type = "primary";
          bootable = true;
          content = {
            type = "lvm_pv";
            vg = "pool";
          };
        }
      ];
    };
  });
  mdadm = {
    boot = {
      type = "mdadm";
      level = 1;
      metadata = "1.0";
      content = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
      };
    };
  };
  lvm_vg = {
    pool = {
      type = "lvm_vg";
      lvs = {
        root = {
          type = "lvm_lv";
          size = "100%FREE";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            options = [
              "defaults"
            ];
          };
        };
      };
    };
  };
}
