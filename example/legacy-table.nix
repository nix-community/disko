{
  disko.devices.disk.main = {
    device = "/dev/sda";
    type = "disk";
  };

  disko.devices.disk.main.content = {
    type = "table";
    format = "gpt";
  };

  disko.devices.disk.main.content.partitions = [
    {
      name = "ESP";
      start = "1M";
      end = "500M";
      bootable = true;
      content = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
      };
    }
    {
      name = "root";
      start = "500M";
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
}

