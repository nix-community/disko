# Example to create a bios compatible gpt partition
{
  type = "devices";
  content = {
    sda = {
      type = "table";
      format = "gpt";
      partitions = [
        {
          type = "partition";
          start = "1MB";
          end = "2MB";
          part-type = "primary";
          flags = ["bios_grub"];
          content.type = "noop";
        }
        {
          type = "partition";
          # leave space for the grub aka BIOS boot
          start = "2MB";
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
  };
}
