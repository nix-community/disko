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
                filesystem = "mounted_subvolumes_in_multi";
                label = "fallback-test.vdb2";
                extraFormatArgs = [
                  "--discard"
                ];
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
                filesystem = "mounted_subvolumes_in_multi";
                label = "fallback-test.vdc1";
                extraFormatArgs = [
                  "--discard"
                ];
              };
            };
          };
        };
      };
    };

    bcachefs_filesystems = {
      mounted_subvolumes_in_multi = {
        type = "bcachefs_filesystem";
        passwordFile = "/tmp/fallback-secret.key";
        extraFormatArgs = [
          "--compression=lz4"
          "--background_compression=lz4"
        ];

        # TPM2 unlocking configuration (will fail due to missing TPM2 device)
        unlock = {
          enable = true;
          secretFiles = [
            ./secrets/tpm.jwe
            ./secrets/fido.jwe
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
