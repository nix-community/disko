{ config, options, lib, diskoLib, parent, device, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "luks" ];
      internal = true;
      description = "Type";
    };
    device = lib.mkOption {
      type = lib.types.str;
      description = "Device to encrypt";
      default = device;
    };
    name = lib.mkOption {
      type = lib.types.str;
      description = "Name of the LUKS";
    };
    keyFile = lib.mkOption {
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = "DEPRECATED use passwordFile or settings.keyFile. Path to the key for encryption";
      example = "/tmp/disk.key";
    };
    passwordFile = lib.mkOption {
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = "Path to the file which contains the password for initial encryption";
      example = "/tmp/disk.key";
    };
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "LUKS settings (as defined in configuration.nix in boot.initrd.luks.devices.<name>)";
      example = ''{
          keyFile = "/tmp/disk.key";
          keyFileSize = 2048;
          keyFileOffset = 1024;
          fallbackToPassword = true;
          allowDiscards = true;
        };
      '';
    };
    additionalKeyFiles = lib.mkOption {
      type = lib.types.listOf diskoLib.optionTypes.absolute-pathname;
      default = [ ];
      description = "Path to additional key files for encryption";
      example = [ "/tmp/disk2.key" ];
    };
    initrdUnlock = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to add a boot.initrd.luks.devices entry for the specified disk.";
    };
    extraFormatArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments to pass to `cryptsetup luksFormat` when formatting";
      example = [ "--pbkdf argon2id" ];
    };
    extraOpenArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments to pass to `cryptsetup luksOpen` when opening";
      example = [ "--timeout 10" ];
    };

    hashContent = diskoLib.deviceType {
      parent = config;
      device = "/dev/mapper/${config.name}";
    };

    _parent = lib.mkOption {
      internal = true;
      default = parent;
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = dev:
        lib.optionalAttrs (config.content != null) (config.content._meta dev);
      description = "Metadata";
    };
    #if ! blkid "${config.device}" >/dev/null || ! (blkid "${config.device}" -o export | grep -q '^TYPE='); then
    #  ${lib.optionalString config.askPassword ''
    #    askPassword() {
    #      if [ -z ''${IN_DISKO_TEST+x} ]; then
    #        set +x
    #        echo "Enter password for ${config.device}: "
    #        IFS= read -r -s password
    #        echo "Enter password for ${config.device} again to be safe: "
    #        IFS= read -r -s password_check
    #        export password
    #        [ "$password" = "$password_check" ]
    #        set -x
    #      else
    #        export password=disko
    #      fi
    #    }
    #    until askPassword; do
    #      echo "Passwords did not match, please try again."
    #    done
    #  ''}
    #  cryptsetup -q luksFormat "${config.device}" ${toString config.extraFormatArgs} ${keyFileArgs}
    #  ${cryptsetupOpen} --persistent
    #  ${toString (lib.forEach config.additionalKeyFiles (keyFile: ''
    #    cryptsetup luksAddKey "${config.device}" ${keyFile} ${keyFileArgs}
    #  ''))}
    #fi
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = "";
    };
    # For mount we mount the underlying device instead of the verity device, so we can update its content.
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default =
    };
    _umount = diskoLib.mkUmountOption {
      inherit config options;
      default = ''
        ${lib.optionalString (config.content != null) config.creationTimeContent._umount}
        veritysetup format 
      '';
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = [ ]
        # If initrdUnlock is true, then add a device entry to the initrd.luks.devices config.
        ++ (lib.optional config.initrdUnlock [
        {
          boot.initrd.luks.devices.${config.name} = {
            inherit (config) device;
          } // config.settings;
        }
      ]) ++ (lib.optional (config.content != null) config.content._config);
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ pkgs.gnugrep pkgs.cryptsetup ] ++ (lib.optionals (config.content != null) (config.content._pkgs pkgs));
      description = "Packages";
    };
  };
}
