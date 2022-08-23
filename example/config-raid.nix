# usage: nix-instantiate --eval --json --strict example/config.nix | jq .
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
            type = "mdraid";
            name = "root";
            content = {
              # only specify the filesystem once per raid, all other needs to be noop
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        }
      ];
    };
    sdb = {
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
          start = "2M";
          end = "100%";
          part-type = "primary";
          bootable = true;
          content = {
            type = "mdraid";
            name = "root";
            content.type = "noop";
          };
        }
      ];
    };
  };
}
