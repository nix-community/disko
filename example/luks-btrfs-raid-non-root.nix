# creates 4x luks containers on 4x nvme drives
# then creates a single btrfs RAID 10 volume across them
# this is not intended to be used as a root/boot device, rather as encrypted data storage
# each device has its own luks key
# instead use `disko-mount` to mount them
# disko-mount can be added to your system by adding the following to your configuration.nix
#   environment.systemPackages = [ config.system.build.mount ];

{
  disko.devices = {
    disk = {
      # Devices will be mounted and formatted in alphabetical order, and btrfs can only mount raids
      # when all devices are present. So we define an "empty" luks device on the first 3 disks,
      # and the actual btrfs raid on the last disk, and the name of these entries matters!
      disk0 = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
            type = "luks";
            name = "disk0"; # device-mapper name when decrypted
            initrdUnlock = false; # dont try to unlock this in the initrd
            settings = {
              allowDiscards = true;
          };
        };
      };
      disk1 = {
        type = "disk";
        device = "/dev/nvme1n1";
        content = {
            type = "luks";
            name = "disk1"; # device-mapper name when decrypted
            initrdUnlock = false; # dont try to unlock this in the initrd
            settings = {
              allowDiscards = true;
          };
        };
      };
      disk2 = {
        type = "disk";
        device = "/dev/nvme2n1";
        content = {
            type = "luks";
            name = "disk2"; # device-mapper name when decrypted
            initrdUnlock = false; # dont try to unlock this in the initrd
            settings = {
              allowDiscards = true;
          };
        };
      };
      disk3 = {
        type = "disk";
        device = "/dev/nvme3n1";
        content = {
          type = "luks";
          name = "disk3"; # device-mapper name when decrypted
          initrdUnlock = false; # dont try to unlock this in the initrd
          settings = {
            allowDiscards = true;
          };
          content = {
            type = "btrfs";
            extraArgs = [
              "-d raid10"
              "/dev/mapper/disk0" # Use decrypted mapped device, same name as defined in disk0
              "/dev/mapper/disk1" # Use decrypted mapped device, same name as defined in disk1
              "/dev/mapper/disk2" # Use decrypted mapped device, same name as defined in disk2
              # disk3 is passed in by by default
            ];
            subvolumes = {
              "data" = {

                mountpoint = "/data";
                mountOptions = [
                  "defaults" # use the sane btrfs mount defaults
                  "noauto" # ensure that systemd doesnt try to mount this at boot
                  "nofail" # ensure that systemd failing to mount this doesn't send us to emergency mode
                  "noatime"
                  "ssd"
                ];
              };
            };
          };
        };
      };
      # included a simple root fs to make the test framework happy
      # swap this with any solution for your rootfs, or drop it completely
      # its not the focus of this example
      adisk = {
        device = "/dev/mmcblk0";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "500M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
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
      };
    };
  };
}
