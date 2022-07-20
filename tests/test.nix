{
  nixpkgs ? <nixpkgs>,
  diskoLib ? import ../. {},
}:
import (nixpkgs + "/nixos/tests/make-test-python.nix") ({ pkgs, ... }: let

  disko-config = {
    type = "devices";
    content = {
      vdb = {
        type = "table";
        format = "gpt";
        partitions = [
          {
            type = "partition";
            part-type = "ESP";
            start = "1MiB";
            end = "100MiB";
            fs-type = "FAT32";
            bootable = true;
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              options = [
                "defaults"
              ];
            };
          }
          {
            type = "partition";
            part-type = "primary";
            start = "100MiB";
            end = "100%";
            content = {
              type = "luks";
              algo = "aes-xts...";
              name = "crypted";
              keyfile = "/tmp/secret.key";
              extraArgs = [
                "--hash sha512"
                "--iter-time 5000"
              ];
              content = {
                type = "lvm";
                name = "pool";
                lvs = {
                  root = {
                    type = "lv";
                    size = "100M";
                    mountpoint = "/";
                    content = {
                      type = "filesystem";
                      format = "ext4";
                      mountpoint = "/";
                      options = [
                        "defaults"
                      ];
                    };
                  };
                  home = {
                    type = "lv";
                    size = "10M";
                    content = {
                      type = "filesystem";
                      format = "ext4";
                      mountpoint = "/home";
                    };
                  };
                  raw = {
                    type = "lv";
                    size = "10M";
                    content = {
                      type = "noop";
                    };
                  };
                };
              };
            };
          }
        ];
      };
    };
  };

in {
  name = "disko";

  nodes.machine =
    { config, pkgs, ... }:

    {
      imports = [
        (nixpkgs + "/nixos/modules/profiles/installation-device.nix")
        (nixpkgs + "/nixos/modules/profiles/base.nix")
      ];

      virtualisation.emptyDiskImages = [ 512 ];
    };

  testScript =
    ''
      machine.succeed("echo 'secret' > /tmp/secret.key");
      machine.succeed("${pkgs.writeScript "create" (diskoLib.create disko-config)}");
      machine.succeed("${pkgs.writeScript "mount" (diskoLib.mount disko-config)}");
      machine.succeed("test -b /dev/mapper/pool-raw");
    '';

})
