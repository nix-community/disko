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
                passwordFile = "/tmp/secret.key";
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
    name = "luks-interactive-login";
    enableOCR = true;
    bootCommands = ''
      machine.wait_for_text("[Pp]assphrase for")
      machine.send_chars("secretsecret\n")
    '';
    extraChecks = ''
      machine.succeed("cryptsetup isLuks /dev/vda2");
    '';
  };
}
