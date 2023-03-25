{ config, options, lib, diskoLib, optionTypes, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "luks" ];
      internal = true;
      description = "Type";
    };
    name = lib.mkOption {
      type = lib.types.str;
      description = "Name of the LUKS";
    };
    keyFile = lib.mkOption {
      type = lib.types.nullOr optionTypes.absolute-pathname;
      default = null;
      description = "Path to the key for encryption";
    };
    keyFileSize = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Size of the key file, in bytes";
    };
    keyFileOffset = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Offset of the key file, in bytes";
    };
    extraFormatArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments to pass to `cryptsetup luksFormat` when formatting";
    };
    extraOpenArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments to pass to `cryptsetup luksOpen` when opening";
      example = [ "--allow-discards" ];
    };
    content = diskoLib.deviceType;
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
      default = { dev }:
        let
          hasKeyFile = config.keyFile != null;
          hasKeyFileSize = hasKeyFile && (config.keyFileSize != null);
          hasKeyFileOffset = hasKeyFile && (config.keyFileOffset != null);
        in
        ''
          cryptsetup -q luksFormat ${dev} \
            ${diskoLib.maybeStr config.keyFile} \
            ${lib.optionalString hasKeyFileSize "--keyfile-size ${toString config.keyFileSize}"} \
            ${lib.optionalString hasKeyFileOffset "--keyfile-offset ${toString config.keyFileOffset}"} \
            ${toString config.extraFormatArgs}
          cryptsetup luksOpen ${dev} ${config.name} \
            ${lib.optionalString hasKeyFile "--key-file ${config.keyFile}"} \
            ${lib.optionalString hasKeyFileSize "--keyfile-size ${toString config.keyFileSize}"} \
            ${lib.optionalString hasKeyFileOffset "--keyfile-offset ${toString config.keyFileOffset}"} \
            ${toString config.extraOpenArgs}
          ${lib.optionalString (config.content != null) (config.content._create {dev = "/dev/mapper/${config.name}";})}
        '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { dev }:
        let
          contentMount = config.content._mount { dev = "/dev/mapper/${config.name}"; };
          hasKeyFile = config.keyFile != null;
          hasKeyFileSize = hasKeyFile && (config.keyFileSize != null);
          hasKeyFileOffset = hasKeyFile && (config.keyFileOffset != null);
        in
        {
          dev = ''
            cryptsetup status ${config.name} >/dev/null 2>/dev/null ||
              cryptsetup luksOpen ${dev} ${config.name} \
                ${lib.optionalString hasKeyFile "--key-file ${config.keyFile}"} \
                ${lib.optionalString hasKeyFileSize "--keyfile-size ${toString config.keyFileSize}"} \
                ${lib.optionalString hasKeyFileOffset "--keyfile-offset ${toString config.keyFileOffset}"}
            ${lib.optionalString (config.content != null) contentMount.dev or ""}
          '';
          fs = lib.optionalAttrs (config.content != null) contentMount.fs or { };
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = dev:
        [
          # TODO do we need this always in initrd and only there?
          { boot.initrd.luks.devices.${config.name}.device = dev; }
        ] ++ (lib.optional (config.content != null) (config.content._config "/dev/mapper/${config.name}"));
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
