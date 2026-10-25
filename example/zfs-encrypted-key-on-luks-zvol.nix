{ lib, config, utils, ... }:
{
  disko.devices = {
    disk.disk1 = {
      type = "disk";
      device = "/dev/vda";
      content = {
        type = "gpt";
        partitions = {
          esp = {
            name = "ESP";
            size = "500M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "rpool";
            };
          };
        };
      };
    };
    zpool = {
      rpool = {
        type = "zpool";
        rootFsOptions = {
          mountpoint = "none";
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          "com.sun:auto-snapshot" = "true";
        };
        options.ashift = "12";
        datasets = {
          credstore = {
            type = "zfs_volume";
            size = "100M";
            content = {
              type = "luks";
              name = "credstore";
              content = {
                type = "filesystem";
                format = "ext4";
              };
            };
          };
          crypt = {
            type = "zfs_fs";
            options.mountpoint = "none";
            options.encryption = "aes-256-gcm";
            options.keyformat = "raw";
            options.keylocation = "file:///etc/credstore/zfs-sysroot.mount";
            preCreateHook = "mount -o X-mount.mkdir /dev/mapper/credstore /etc/credstore && head -c 32 /dev/urandom > /etc/credstore/zfs-sysroot.mount";
            postCreateHook = "umount /etc/credstore && cryptsetup luksClose /dev/mapper/credstore";
          };
          "crypt/system" = {
            type = "zfs_fs";
            mountpoint = "/";
          };
          "crypt/system/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
          };
          "crypt/system/var" = {
            type = "zfs_fs";
            mountpoint = "/var";
          };
        };
      };
    };
  };
  boot.initrd.systemd.emergencyAccess = false;
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd = {
    # This would be a nightmare without systemd initrd
    systemd.enable = true;

    # Disable NixOS's systemd service that imports the pool
    systemd.services.zfs-import-rpool.enable = false;

    systemd.services.import-rpool-bare = let
      # Compute the systemd units for the devices in the pool
      devices = map (p: utils.escapeSystemdPath p + ".device") [
        config.disko.devices.disk.disk1.device
      ];
    in {
      after = [ "modprobe@zfs.service" ] ++ devices;
      requires = [ "modprobe@zfs.service" ];

      # Devices are added to 'wants' instead of 'requires' so that a
      # degraded import may be attempted if one of them times out.
      # 'cryptsetup-pre.target' is wanted because it isn't pulled in
      # normally and we want this service to finish before
      # 'systemd-cryptsetup@.service' instances begin running.
      wants = [ "cryptsetup-pre.target" ] ++ devices;
      before = [ "cryptsetup-pre.target" ];

      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ config.boot.zfs.package ];
      enableStrictShellChecks = true;
      script = let
        # Check that the FSes we're about to mount actually come from
        # our encryptionroot. If not, they may be fraudulent.
        shouldCheckFS = fs: fs.fsType == "zfs" && utils.fsNeededForBoot fs;
        checkFS = fs: ''
          encroot="$(zfs get -H -o value encryptionroot ${fs.device})"
          if [ "$encroot" != rpool/crypt ]; then
            echo ${fs.device} has invalid encryptionroot "$encroot" >&2
            exit 1
          else
            echo ${fs.device} has valid encryptionroot "$encroot" >&2
          fi
        '';
      in ''
        function cleanup() {
          exit_code=$?
          if [ "$exit_code" != 0 ]; then
            zpool export rpool
          fi
        }
        trap cleanup EXIT
        zpool import -N -d /dev/disk/by-id rpool

        # Check that the file systems we will mount have the right encryptionroot.
        ${lib.concatStringsSep "\n" (lib.map checkFS (lib.filter shouldCheckFS config.system.build.fileSystems))}
      '';
    };

    luks.devices.credstore = {
      device = "/dev/zvol/rpool/credstore";
      # 'tpm2-device=auto' usually isn't necessary, but for reasons
      # that bewilder me, adding 'tpm2-measure-pcr=yes' makes it
      # required. And 'tpm2-measure-pcr=yes' is necessary to make sure
      # the TPM2 enters a state where the LUKS volume can no longer be
      # decrypted. That way if we accidentally boot an untrustworthy
      # OS somehow, they can't decrypt the LUKS volume.
      crypttabExtraOpts = [ "tpm2-measure-pcr=yes" "tpm2-device=auto" ];
    };
    # Adding an fstab is the easiest way to add file systems whose
    # purpose is solely in the initrd and aren't a part of '/sysroot'.
    # The 'x-systemd.after=' might seem unnecessary, since the mount                                                                                                
    # unit will already be ordered after the mapped device, but it
    # helps when stopping the mount unit and cryptsetup service to
    # make sure the LUKS device can close, thanks to how systemd
    # orders the way units are stopped.
    supportedFilesystems.ext4 = true;
    systemd.contents."/etc/fstab".text = ''
      /dev/mapper/credstore /etc/credstore ext4 defaults,x-systemd.after=systemd-cryptsetup@credstore.service 0 2
    '';
    # Add some conflicts to ensure the credstore closes before leaving initrd.
    systemd.targets.initrd-switch-root = {
      conflicts = [ "etc-credstore.mount" "systemd-cryptsetup@credstore.service" ];
      after = [ "etc-credstore.mount" "systemd-cryptsetup@credstore.service" ];
    };

    # After the pool is imported and the credstore is mounted, finally
    # load the key. This uses systemd credentials, which is why the
    # credstore is mounted at '/etc/credstore'. systemd will look
    # there for a credential file called 'zfs-sysroot.mount' and
    # provide it in the 'CREDENTIALS_DIRECTORY' that is private to
    # this service. If we really wanted, we could make the credstore a
    # 'WantsMountsFor' instead and allow providing the key through any
    # of the numerous other systemd credential provision mechanisms.
    systemd.services.rpool-load-key = {
      requiredBy = [ "initrd.target" ];
      before = [ "sysroot.mount" "initrd.target" ];
      requires = [ "import-rpool-bare.service" ];
      after = [ "import-rpool-bare.service" ];
      unitConfig.RequiresMountsFor = "/etc/credstore";
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        ImportCredential = "zfs-sysroot.mount";
        RemainAfterExit = true;
        ExecStart = "${config.boot.zfs.package}/bin/zfs load-key -L file://\"\${CREDENTIALS_DIRECTORY}\"/zfs-sysroot.mount rpool/crypt";
      };
    };
  };

  # All my datasets use 'mountpoint=$path', but you have to be careful
  # with this. You don't want any such datasets to be mounted via
  # 'fileSystems', because it will cause issues when
  # 'zfs-mount.service' also tries to do so. But that's only true in
  # stage 2. For the '/sysroot' file systems that have to be mounted
  # in stage 1, we do need to explicitly add them, and we need to add
  # the 'zfsutil' option. For my pool, that's the '/', '/nix', and
  # '/var' datasets.
  #
  # All of that is incorrect if you just use 'mountpoint=legacy'
  fileSystems = lib.genAttrs [ "/" "/nix" "/var" ] (fs: {
    device = "rpool/crypt/system${lib.optionalString (fs != "/") fs}";
    fsType = "zfs";
    options = [ "zfsutil" ];
  });
}
