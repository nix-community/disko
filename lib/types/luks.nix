{ config, options, lib, diskoLib, parent, ... }:
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
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = "Path to the key for encryption";
      example = "/tmp/disk.key";
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
    content = diskoLib.deviceType { parent = config; };
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
      default = { dev }: ''
        cryptsetup -q luksFormat ${dev} ${diskoLib.maybeStr config.keyFile} ${toString config.extraFormatArgs}
        cryptsetup luksOpen ${dev} ${config.name} ${toString config.extraOpenArgs} ${lib.optionalString (config.keyFile != null) "--key-file ${config.keyFile}"}
        ${lib.optionalString (config.content != null) (config.content._create {dev = "/dev/mapper/${config.name}";})}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { dev }:
        let
          contentMount = config.content._mount { dev = "/dev/mapper/${config.name}"; };
        in
        {
          dev = ''
            cryptsetup status ${config.name} >/dev/null 2>/dev/null ||
              cryptsetup luksOpen ${dev} ${config.name} ${lib.optionalString (config.keyFile != null) "--key-file ${config.keyFile}"}
            ${lib.optionalString (config.content != null) contentMount.dev or ""}
          '';
          fs = lib.optionalAttrs (config.content != null) contentMount.fs or { };
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = dev: [ ]
        # If initrdUnlock is true, then add a device entry to the initrd.luks.devices config.
        ++ (lib.optional config.initrdUnlock [{ boot.initrd.luks.devices.${config.name}.device = dev; }])
        ++ (lib.optional (config.content != null) (config.content._config "/dev/mapper/${config.name}"));
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
