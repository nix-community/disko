# Example to create a bios compatible gpt partition
{
  disks ? [ "/dev/vdb" ],
  lib,
  ...
}:
{
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
  _module.args.disks = [ "/dev/vdb" ];
  disko.test = {
    name = "with-lib";
    efi = false;
    extraChecks = ''
      machine.succeed("mountpoint /");
    '';
  };
}
