{
  disko.devices = {
    disk = {
      vdb = {
        device = "/dev/vdb";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdb1 = {
              type = "EF00";
              size = "100M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            vdb2 = {
              size = "25%";
              content = {
                type = "bcachefs";
                filesystem = "empty_test";
                label = "edge-empty.vdb2";
              };
            };

            vdb3 = {
              size = "25%";
              content = {
                type = "bcachefs";
                filesystem = "corrupted_test";
                label = "edge-corrupted.vdb3";
              };
            };

            vdb4 = {
              size = "25%";
              content = {
                type = "bcachefs";
                filesystem = "missing_test";
                label = "edge-missing.vdb4";
              };
            };

            vdb5 = {
              size = "25%";
              content = {
                type = "bcachefs";
                filesystem = "multi_test";
                label = "edge-multi.vdb5";
              };
            };
          };
        };
      };

      vdc = {
        device = "/dev/vdc";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdc1 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "malformed_test";
                label = "edge-malformed.vdc1";
              };
            };
          };
        };
      };

      vdd = {
        device = "/dev/vdd";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            vdd1 = {
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "single_device_test";
                label = "edge-single.vdd1";
              };
            };
          };
        };
      };
    };

    bcachefs_filesystems = {
      # Test 1: Empty configuration (unlock enabled but no secret files)
      empty_test = {
        type = "bcachefs_filesystem";
        passwordFile = "/tmp/secret.key";
        unlock = {
          enable = true;
          secretFiles = [ ];
        };
      };

      # Test 2: Corrupted JWE file
      corrupted_test = {
        type = "bcachefs_filesystem";
        passwordFile = "/tmp/secret.key";
        unlock = {
          enable = true;
          secretFiles = [ ./secrets/corrupted.jwe ];
        };
      };

      # Test 3: Missing secret files directory (unlock disabled)
      missing_test = {
        type = "bcachefs_filesystem";
        passwordFile = "/tmp/secret.key";
        unlock = {
          enable = false;
        };
      };

      # Test 4: Multiple valid keys
      multi_test = {
        type = "bcachefs_filesystem";
        passwordFile = "/tmp/secret.key";
        unlock = {
          enable = true;
          secretFiles = [
            ./secrets/tpm.jwe
            ./secrets/fido.jwe
            ./secrets/tang.jwe
          ];
          extraPackages = [ ];
        };
      };

      # Test 5: Malformed JWE files
      malformed_test = {
        type = "bcachefs_filesystem";
        passwordFile = "/tmp/secret.key";
        unlock = {
          enable = true;
          secretFiles = [ ./secrets/invalid.jwe ];
        };
      };

      # Test 6: Single device configuration
      single_device_test = {
        type = "bcachefs_filesystem";
        passwordFile = "/tmp/secret.key";
        unlock = {
          enable = true;
          secretFiles = [ ./secrets/tpm.jwe ];
        };
      };
    };
  };
}
