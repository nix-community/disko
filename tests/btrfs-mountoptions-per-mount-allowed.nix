{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "btrfs-mountoptions-per-mount-allowed";
  disko-config = pkgs.lib.recursiveUpdate (import ../example/btrfs-subvolumes.nix) {
    disko.devices.disk.main.content.partitions.root.content.subvolumes = {
      "/home".mountOptions = [ "noexec" ];
      "/nosuid" = {
        mountpoint = "/nosuid";
        mountOptions = [ "nosuid" ];
      };
      "/nodev" = {
        mountpoint = "/nodev";
        mountOptions = [ "nodev" ];
      };
      "/noatime" = {
        mountpoint = "/noatime";
        mountOptions = [ "noatime" ];
      };
    };
  };
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("mountpoint /home");
    machine.succeed("mountpoint /nosuid");
    machine.succeed("mountpoint /nodev");
    machine.succeed("mountpoint /noatime");
    machine.succeed("findmnt -no OPTIONS /home | tr ',' '\n' | grep -qx noexec");
    machine.succeed("findmnt -no OPTIONS /nosuid | tr ',' '\n' | grep -qx nosuid");
    machine.succeed("findmnt -no OPTIONS /nodev | tr ',' '\n' | grep -qx nodev");
    machine.succeed("findmnt -no OPTIONS /noatime | tr ',' '\n' | grep -qx noatime");
    machine.fail("findmnt -no OPTIONS / | tr ',' '\n' | grep -qx noexec");
    machine.fail("findmnt -no OPTIONS / | tr ',' '\n' | grep -qx nosuid");
    machine.fail("findmnt -no OPTIONS / | tr ',' '\n' | grep -qx nodev");
    machine.fail("findmnt -no OPTIONS / | tr ',' '\n' | grep -qx noatime");
  '';
}
