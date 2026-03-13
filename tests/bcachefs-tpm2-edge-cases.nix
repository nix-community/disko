{ pkgs, makeTest, ... }:

let
  diskoLib = pkgs.callPackage ../lib { };
in
diskoLib.testLib.makeDiskoTest {
  name = "bcachefs-tpm2-edge-cases";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ (import ../module.nix) ];
      virtualisation.emptyDiskImages = [ 4096 ];

      environment.systemPackages = with pkgs; [
        bcachefs-tools
        clevis
        jose
        tpm2-tools
      ];

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
                  name = "test-edge";
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

  testScript = ''
    machine.start()
    machine.succeed("test -d /etc/bcachefs-keys/test-edge")
    machine.succeed("test -f /etc/bcachefs-keys/test-edge/tpm.jwe")
    print("✅ Edge cases test passed!")
  '';
}
