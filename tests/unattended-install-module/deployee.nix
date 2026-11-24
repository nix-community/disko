{
  config,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [
    ./common.nix
    "${modulesPath}/profiles/qemu-guest.nix"
    # When writing NixOS tests, you normally declare NixOS configurations by
    # doing something like this:
    #
    # { pkgs }:
    # pkgs.testers.runNixOSTest {
    #   name = "example-test";
    #   nodes.exampleMachine = {
    #     networking.hostName = "example-machine";
    #   };
    #   testScript = ''
    #     exampleMachine.succeed("true")
    #   '';
    # }
    #
    # In that example, test-instrumentation.nix automatically gets imported for
    # exampleMachine because exampleMachine is a part of the nodes attribute
    # set.
    #
    # This deployee configuration is not going to be a part of the nodes
    # attribute set, so we have to import test-instrumentation.nix manually.
    "${modulesPath}/testing/test-instrumentation.nix"
  ];

  system.stateVersion = config.system.nixos.release;

  disko.devices.disk.main = {
    device = "/dev/vdb";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        efiSystemPartition = {
          type = "EF00";
          size = "512M";
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

  networking.hostName = "deployee";
}
