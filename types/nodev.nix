{ lib, config, options, diskoLib, optionTypes, rootMountPoint, ... }:
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
      type = optionTypes.absolute-pathname;
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
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = _: "";
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = _: {
        fs.${config.mountpoint} = ''
          if ! findmnt ${config.fsType} "${rootMountPoint}${config.mountpoint}" > /dev/null 2>&1; then
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
      default = [{
        fileSystems.${config.mountpoint} = {
          inherit (config) device;
          inherit (config) fsType;
          options = config.mountOptions;
        };
      }];
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ ];
      description = "Packages";
    };
  };
}
