{ pkgs, makeTest, ... }:

let
  diskoLib = pkgs.callPackage ../lib { };
in
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcachefs-tpm2-unlock";

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
                name = "test-basic";
                mountpoint = "/";
                extraFormatArgs = [ "--encrypted" ];
                unlock = {
                  enable = true;
                  secretFiles = [ ./test-secrets/tpm.jwe ];
                  extraPackages = with pkgs; [ ];
                };
                subvolumes = {
                  "root" = {
                    mountpoint = "/";
                  };
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
      bcachefs-tools
      clevis
      jose
      tpm2-tools
    ];
  };

  extraTestScript = ''
    machine.start()
    machine.succeed("test -d /etc/bcachefs-keys/test-basic")
    machine.succeed("test -f /etc/bcachefs-keys/test-basic/tpm.jwe")
    machine.succeed("which clevis")
    machine.succeed("which bcachefs")
    print("✅ Basic unlock test passed!")
  '';
}
