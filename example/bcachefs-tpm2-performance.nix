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
              size = "100%";
              content = {
                type = "bcachefs";
                filesystem = "perf_test";
                label = "performance-test";
                extraFormatArgs = [
                  "--discard"
                  "--compression=lz4"
                ];
              };
            };
          };
        };
      };
    };

    bcachefs_filesystems = {
      perf_test = {
        type = "bcachefs_filesystem";
        passwordFile = "/tmp/perf-secret.key";
        extraFormatArgs = [
          "--compression=lz4"
          "--background_compression=lz4"
        ];

        # Performance test configuration with multiple keys
        unlock = {
          enable = true;
          secretFiles = [
            ./secrets/tpm.jwe
            ./secrets/fido.jwe
            ./secrets/tang.jwe
          ];
          extraPackages = [ ];
        };

        subvolumes = {
          "subvolumes/root" = {
            mountpoint = "/";
            mountOptions = [ "verbose" ];
          };
          "subvolumes/home" = {
            mountpoint = "/home";
          };
          "subvolumes/nix" = {
            mountpoint = "/nix";
          };
        };
      };
    };
  };
}
