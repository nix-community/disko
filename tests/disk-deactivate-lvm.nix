{
  pkgs,
  ...
}:
let
  inherit (pkgs) lib;

  # LVM allows `+`, `_`, `.` and `-` in names
  oldVg = "old_vg-01";
  # device-mapper escapes `-` inside VG/LV names as `--`
  oldVgDm = "old_vg--01";
in
pkgs.testers.runNixOSTest {
  name = "disko-disk-deactivate-lvm";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ ../module.nix ];

      disko = {
        enableConfig = false;
        checkScripts = true;
        # The partition boundaries differ from the old layout created in the
        # test script, so the kernel can only pick up the new partition table
        # if nothing holds the old partitions open anymore.
        devices.disk.main = {
          device = "/dev/vdb";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              boot = {
                size = "1M";
                type = "EF02";
              };
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

      virtualisation.emptyDiskImages = [ 4096 ];

      environment.systemPackages = with pkgs; [
        dosfstools
        gptfdisk
        lvm2
        xfsprogs
      ];
    };

  testScript =
    { nodes, ... }:
    ''
      machine.wait_for_unit("multi-user.target")

      with subtest("Create a foreign layout with an active LVM volume group"):
          machine.succeed(
              "sgdisk -n 1:0:+100M -t 1:EF00 -n 2:0:+500M -n 3:0:0 -t 3:8E00 /dev/vdb",
              "udevadm settle",
              "mkfs.vfat /dev/vdb1",
              "mkfs.xfs /dev/vdb2",
              "pvcreate /dev/vdb3",
              "vgcreate ${oldVg} /dev/vdb3",
              "lvcreate -y -L 256M -n swap ${oldVg}",
              "lvcreate -y -l 100%FREE -n root ${oldVg}",
              "mkswap /dev/${oldVg}/swap",
              "mkfs.xfs /dev/${oldVg}/root",
          )
          machine.succeed("vgchange -a y", "udevadm settle")
          machine.succeed("test -b /dev/mapper/${oldVgDm}-swap")
          machine.succeed("test -b /dev/mapper/${oldVgDm}-root")

      with subtest("disko replaces the foreign layout"):
          machine.succeed("${lib.getExe nodes.machine.system.build.destroyFormatMount} --yes-wipe-all-disks")
          machine.succeed("mountpoint /mnt")
          machine.succeed("mountpoint /mnt/boot")

      with subtest("The old volume group is gone"):
          machine.fail("vgs ${oldVg}")
          machine.fail("dmsetup ls | grep -F ${oldVgDm}")
    '';
}
