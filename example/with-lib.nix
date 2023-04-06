# Example to create a bios compatible gpt partition
{ disks ? [ "/dev/vdb" ], lib, ... }: {
  disko.devices = {
    disk = lib.genAttrs [ (lib.head disks) ] (device: {
      device = device;
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
            flags = [ "bios_grub" ];
          }
          {
            name = "root";
            type = "partition";
            # leave space for the grub aka BIOS boot
            start = "1M";
            end = "100%";
            part-type = "primary";
            bootable = true;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          }
        ];
      };
    });
  };
}
