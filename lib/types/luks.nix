{ config, options, lib, diskoLib, parent, device, ... }:
let
  keyFile =
    if config.settings ? "keyFile"
    then config.settings.keyFile
    else if config.askPassword
    then ''<(set +x; echo -n "$password"; set -x)''
    else if config.passwordFile != null
    # do not print the password to the console
    then ''<(set +x; echo -n "$(cat ${config.passwordFile})"; set -x)''
    else if config.keyFile != null
    then
      lib.warn
        ("The option `keyFile` is deprecated."
          + "Use passwordFile instead if you want to use interactive login or settings.keyFile if you want to use key file login")
        config.keyFile
    else if config.clevisPin != null
    then
      lib.warn
        ("You are using clevisPin only without any passphrase or keyFile."
          + "If you loose access to your pins the data on your disk will be lost")
        ''<(echo -n "clevis-temp-passphrase")''
    else null;
  keyFileArgs = ''
    ${lib.optionalString (keyFile != null) "--key-file ${keyFile}"} \
    ${lib.optionalString (lib.hasAttr "keyFileSize" config.settings) "--keyfile-size ${builtins.toString config.settings.keyFileSize}"} \
    ${lib.optionalString (lib.hasAttr "keyFileOffset" config.settings) "--keyfile-offset ${builtins.toString config.settings.keyFileOffset}"} \
  '';
  cryptsetupOpen = ''
    cryptsetup open ${config.device} ${config.name} \
      ${lib.optionalString (config.settings.allowDiscards or false) "--allow-discards"} \
      ${lib.optionalString (config.settings.bypassWorkqueues or false) "--perf-no_read_workqueue --perf-no_write_workqueue"} \
      ${toString config.extraOpenArgs} \
      ${keyFileArgs} \
  '';
in
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
    askPassword = lib.mkOption {
      type = lib.types.bool;
      default = config.keyFile == null && config.passwordFile == null && (! config.settings ? "keyFile") && (config.clevisPin == null);
      description = "Whether to ask for a password for initial encryption";
    };
    clevisPin = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["tpm2" "tang" "sss"]);
      default = null;
      description = "Pin the encrypted volume to a clevis backend";
      example = "tang";
    };
    clevisPinConfig = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "{}";
      description = "Configuration for the clevis backend";
      example = "{\"url\": \"http://tang-server\"}";
    };
    settings = lib.mkOption {
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
      description = "Extra arguments to pass to `cryptsetup open` when opening";
      example = [ "--timeout 10" ];
    };
    content = diskoLib.deviceType { parent = config; device = "/dev/mapper/${config.name}"; };
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
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        ${lib.optionalString config.askPassword ''
          set -x
          askPassword() {
            echo "Enter password for ${config.device}: "
            IFS= read -r -s password
            echo "Enter password for ${config.device} again to be safe: "
            IFS= read -r -s password_check
            export password
            [ "$password" = "$password_check" ]
          }
          until askPassword; do
            echo "Passwords did not match, please try again."
          done
          set -x
        ''}
        cryptsetup -q luksFormat ${config.device} ${toString config.extraFormatArgs} ${keyFileArgs}
        ${cryptsetupOpen} --persistent
        ${toString (lib.forEach config.additionalKeyFiles (keyFile: ''
          cryptsetup luksAddKey ${config.device} ${keyFile} ${keyFileArgs}
        ''))}
        ${lib.optionalString (config.clevisPin != null && keyFile != ''<(echo -n "clevis-temp-passphrase")'') ''
          cryptsetup luksAddKey ${config.device} <(echo -n "clevis-temp-passphrase") ${keyFileArgs}
        ''}
        ${lib.optionalString (config.clevisPin != null) ''
          clevis luks bind -y -k - -d ${config.device} ${config.clevisPin} '${config.clevisPinConfig}' <<< clevis-temp-passphrase
          cryptsetup luksRemoveKey ${config.device} <(echo -n "clevis-temp-passphrase")
        ''}
        ${lib.optionalString (config.content != null) config.content._create}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default =
        let
          contentMount = config.content._mount;
        in
        {
          dev = ''
            if ! cryptsetup status ${config.name} >/dev/null 2>/dev/null; then
              ${lib.optionalString config.askPassword ''
                set +x
                echo "Enter password for ${config.device}"
                IFS= read -r -s password
                export password
                set -x
              ''}
              ${cryptsetupOpen}
            fi
            ${lib.optionalString (config.content != null) contentMount.dev or ""}
          '';
          fs = lib.optionalAttrs (config.content != null) contentMount.fs or { };
        };
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
        ])
        ++ (lib.optional (config.initrdUnlock && (config.clevisPin != null)) [{
          boot.initrd.clevis.enable = true;
          boot.initrd.clevis.devices.${config.name} = {};
        }])
        ++ (lib.optional (config.initrdUnlock && (config.clevisPin == "tang")) [{
          boot.initrd.clevis.useTang = true;
        }])
        ++ (lib.optional (config.content != null) config.content._config);
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ pkgs.cryptsetup ]
        ++ (lib.optionals (config.clevisPin != null) [ pkgs.clevis ])
        ++ (lib.optionals (config.content != null) (config.content._pkgs pkgs));
      description = "Packages";
    };
  };
}
