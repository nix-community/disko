{ config, options, lib, diskoLib, parent, device, ... }:
let
  keyFile = if lib.hasAttr "keyFile" config.settings
    then config.settings.keyFile
    else if config.keyFile != null
    then lib.warn "The option `keyFile` is deprecated. See the `settings` option." config.keyFile
    else null;
  keyFileArgs = ''\
    ${lib.optionalString (keyFile != null) "--key-file ${keyFile}"} \
    ${lib.optionalString (lib.hasAttr "keyFileSize" config.settings) "--keyfile-size ${config.settings.keyFileSize}"} \
    ${lib.optionalString (lib.hasAttr "keyFileOffset" config.settings) "--keyfile-offset ${config.settings.keyFileOffset}"}
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
      description = "Path to the key for encryption";
      example = "/tmp/disk.key";
    };
    settings = lib.mkOption {
      default = { };
      description = "LUKS settings (as defined in configuration.nix in boot.initrd.luks.devices.<name>)";
      example = ''{
          keyFile = "/tmp/disk.key";
          keyFileSize = 2048;
          keyFileOffset = 1024;
          fallbackToPassword = true;
        };
      '';
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
      example = [ "--allow-discards" ];
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
        cryptsetup -q luksFormat ${config.device} ${toString config.extraFormatArgs} \
          ${keyFileArgs}
        cryptsetup luksOpen ${config.device} ${config.name} \
          ${toString config.extraOpenArgs} \
          ${keyFileArgs}
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
            cryptsetup status ${config.name} >/dev/null 2>/dev/null ||
              cryptsetup luksOpen ${config.device} ${config.name} \
              ${keyFileArgs}
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
        ]) ++ (lib.optional (config.content != null) config.content._config);
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ pkgs.cryptsetup ] ++ (lib.optionals (config.content != null) (config.content._pkgs pkgs));
      description = "Packages";
    };
  };
}
