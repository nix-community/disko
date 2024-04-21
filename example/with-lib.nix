# Example to create a bios compatible gpt partition
{ disks ? [ "/dev/vdb" ], lib, ... }: {
  disko.devices = {
    disk = lib.genAttrs disks (device: {
      name = lib.replaceStrings [ "/" ] [ "_" ] device;
      device = device;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1M";
            type = "EF02";
            priority = 1; # Needs to be first partition
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    });
  };
}
