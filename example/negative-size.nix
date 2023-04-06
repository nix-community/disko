{ disks ? [ "/dev/vdb" "/dev/vdc" ], ... }: {
  disko.devices = {
    disk = {
      disk0 = {
        device = builtins.elemAt disks 0;
        type = "disk";
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "nix";
              type = "partition";
              part-type = "primary";
              start = "0%";
              end = "-10MiB";
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
