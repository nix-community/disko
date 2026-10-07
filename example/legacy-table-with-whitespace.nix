# This example with the legacy table should not be used. We recommend using the
# gpt type instead. More information about this warning may be found in the
# documentation.
#
# https://github.com/nix-community/disko/blob/master/docs/table-to-gpt.md
{
  disko.devices = {
    disk = {
      vdb = {
        device = "/dev/sda";
        type = "disk";
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "ESP";
              start = "1MiB";
              end = "100MiB";
              bootable = true;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            }
            {
              name = "name with spaces";
              start = "100MiB";
              end = "200MiB";
              bootable = true;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/name_with_spaces";
              };
            }
            {
              name = "root";
              start = "200MiB";
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
    };
  };
}
