{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/vdb";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "500M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                settings.allowDiscards = true;
                enrollFido2 = true;
                # Do not wait for recovery displaying and blocking formatting.
                enrollRecovery = false;
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
            };
          };
        };
      };
    };
  };
  disko.test = {
    name = "luks-fido2";
    enableCanokey = true;
    extraChecks = ''
      machine.succeed("cryptsetup isLuks /dev/vda2");
      machine.succeed("mountpoint /");
    '';
  };
}
