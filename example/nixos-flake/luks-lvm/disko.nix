# nix build  .#nixosConfigurations.locutus.config.system.build.disko
# nix build  .#nixosConfigurations.locutus.config.system.build.mountScript
# nix build  .#nixosConfigurations.locutus.config.system.build.createScript
# sudo cryptsetup open /dev/nvme0n1p2
# sudo ./result


inputs@{ ... }:
{
  disko = {
    enableConfig = false;
    devices = {
      disk = {
        vdb = {
          type = "disk";
          device = "/dev/sda";
          content = {
            type = "table";
            format = "gpt";
            partitions = [
              {
                type = "partition";
                name = "ESP";
                start = "1MiB";
                end = "100MiB";
                bootable = true;
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [
                    "defaults"
                  ];
                };
              }
              {
                type = "partition";
                name = "luks";
                start = "100MiB";
                end = "100%";
                content = {
                  type = "luks";
                  name = "crypted";
                  #keyFile = "/tmp/secret.key"; # omitting this line will prompt you for a password instead
                  content = {
                    type = "lvm_pv";
                    vg = "pool";
                  };
                };
              }
            ];
          };
        };
      };
      lvm_vg = {
        pool = {
          type = "lvm_vg";
          lvs = {
            root = {
              type = "lvm_lv";
              size = "100M";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [
                  "defaults"
                ];
              };
            };
            raw = {
              type = "lvm_lv";
              size = "10M";
            };
            # lv's are created in alphabetical order, you must consider this if you want to use a relative size
            zhome = {
              type = "lvm_lv";
              size = "+100%FREE";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/home";
              };
            };
          };
        };
      };
    };
  };
}
