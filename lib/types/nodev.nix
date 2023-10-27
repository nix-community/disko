{ lib, config, options, diskoLib, rootMountPoint, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "nodev" ];
      default = "nodev";
      internal = true;
      description = "Device type";
    };
    fsType = lib.mkOption {
      type = lib.types.str;
      description = "File system type";
    };
    device = lib.mkOption {
      type = lib.types.str;
      default = "none";
      description = "Device to use";
    };
    mountpoint = lib.mkOption {
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = config._module.args.name;
      description = "Location to mount the file system at";
    };
    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "defaults" ];
      description = "Options to pass to mount";
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = diskoLib.jsonType;
      default = { };
      description = "Metadata";
    };
    _update = diskoLib.mkCreateOption {
      inherit config options;
      default = "";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = "";
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = lib.optionalAttrs (config.mountpoint != null) {
        fs.${config.mountpoint} = ''
          if ! findmnt --types ${config.fsType} --mountpoint "${rootMountPoint}${config.mountpoint}" > /dev/null 2>&1; then
            mount -t ${config.fsType} ${config.device} "${rootMountPoint}${config.mountpoint}" \
            ${lib.concatMapStringsSep " " (opt: "-o ${opt}") config.mountOptions} \
            -o X-mount.mkdir
          fi
        '';
      };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = lib.optional (config.mountpoint != null) {
        fileSystems.${config.mountpoint} = {
          device = config.device;
          fsType = config.fsType;
          options = config.mountOptions;
        };
      };
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ pkgs.util-linux ];
      description = "Packages";
    };
  };
}
