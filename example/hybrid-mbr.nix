{ disks ? [ "/dev/sda" ], ... }:
{
  disk = {
    main = {
      type = "disk";
      device = builtins.elemAt disks 0;
      content = {
        type = "hybrid_table";
        efiGptPartitionFirst = false;
        hybrid_partitions = [
          {
            type = "hybrid_partition";
            gptPartitionNumber = 1;
            mbrPartitionType = "0x0c";
            mbrBootableFlag = false;
          }
        ];
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              type = "partition";
              name = "TOW-BOOT-FI";
              start = "0%";
              end = "32MiB";
              fs-type = "fat32";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/firmware";
              };
            }
            {
              type = "partition";
              name = "ESP";
              start = "32MiB";
              end = "512MiB";
              bootable = true;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            }
            {
              type = "partition";
              name = "root";
              start = "512MiB";
              end = "100%";
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
