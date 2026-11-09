{ pkgs, makeTest, ... }:

let
  diskoLib = pkgs.callPackage ../lib { };
in
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcachefs-tpm2-unit-tests";

  disko-config = {
    disko.devices = {
      disk.main = {
        device = "/dev/vdb";
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
                type = "bcachefs_filesystem";
                name = "nixos-test";
                mountpoint = "/";
                extraFormatArgs = [ "--encrypted" ];

                unlock = {
                  enable = true;
                  secretFiles = [ ./test-secrets/tpm.jwe ];
                  extraPackages = with pkgs; [ tpm2-tools ];
                };
              };
            };
          };
        };
      };
    };
  };

  extraSystemConfig = {
    environment.systemPackages = with pkgs; [
      clevis
      jose
      tpm2-tools
      bcachefs-tools
    ];
  };

  extraTestScript = ''
    # Test that unlock service is created
    machine.succeed("systemctl status bcachefs-unlock-nixos-test >&2")

    # Test that required packages are available
    machine.succeed("which clevis >&2")
    machine.succeed("which jose >&2") 
    machine.succeed("which tpm2-tools >&2")

    # Test that initrd contains secrets
    machine.succeed("test -f /etc/bcachefs-keys/nixos-test/tpm.jwe >&2")
  '';
}
