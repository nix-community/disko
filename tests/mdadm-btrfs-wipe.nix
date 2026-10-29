{
  pkgs,
  ...
}:
let
  inherit (pkgs) lib;

  diskoModule = ../module.nix;

  diskoConfig = {
    disko.devices.disk = {
      main = {
        device = "/dev/vdb";
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
            encryptedSwap = {
              size = "100%";
              content = {
                type = "swap";
                randomEncryption = true;
              };
            };
          };
        };
      };
    }
    // (lib.genAttrs [ "pool1" "pool2" ] (name: {
      type = "disk";
      device =
        {
          pool1 = "/dev/vdc";
          pool2 = "/dev/vdd";
        }
        .${name};
      content = {
        type = "gpt";
        partitions.mdadm = {
          size = "100%";
          content = {
            type = "mdraid";
            name = "raid0";
          };
        };
      };
    }));

    disko.devices.mdadm.raid0 = {
      type = "mdadm";
      level = 0;
      content = {
        type = "btrfs";
        extraArgs = [ "-f" ];
        mountpoint = "/";
      };
    };
  };
in
pkgs.testers.runNixOSTest {
  name = "disko-btrfs-mdadm-resurrection";

  nodes.machine =
    { config, pkgs, ... }:
    {
      imports = [
        diskoModule
        diskoConfig
      ];

      boot.loader.grub.devices = [ "/dev/null" ];

      virtualisation.emptyDiskImages = [
        4096
        4096
        4096
      ];
      boot.swraid.enable = true;
      environment.systemPackages = with pkgs; [
        mdadm
        btrfs-progs
        cryptsetup
        parted
      ];
    };

  testScript =
    { nodes, ... }:
    let
      inherit (nodes.machine.system.build) destroyScript formatScript mountScript;
    in
    ''
      machine.wait_for_unit("multi-user.target")

      print("Running initial format and mount...")
      machine.succeed("${formatScript}")
      machine.succeed("${mountScript}")

      print("Writing canary file...")
      machine.succeed("echo 'I survived the wipe!' > /mnt/canary.txt")
      machine.succeed("sync")

      machine.succeed("umount -R /mnt")

      print("Running the destroy script...")
      machine.execute("${destroyScript}")

      print("Attempting to reformat and remount...")
      machine.execute("${formatScript}")
      machine.execute("${mountScript}")

      print("Checking if the canary file is still there...")
      status, output = machine.execute("cat /mnt/canary.txt")

      if status == 0 and "I survived the wipe!" in output:
          raise Exception("The canary file survived the Disko wipe process!")
      else:
          print("Test passed: Data was successfully destroyed.")
    '';
}
