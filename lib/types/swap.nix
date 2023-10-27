{ diskoLib, config, options, lib, parent, device, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "swap" ];
      internal = true;
      description = "Type";
    };
    device = lib.mkOption {
      type = lib.types.str;
      default = device;
      description = "Device";
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments";
    };
    randomEncryption = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to randomly encrypt the swap";
    };
    resumeDevice = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to use this as a boot.resumeDevice";
    };
    _parent = lib.mkOption {
      internal = true;
      default = parent;
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = _dev: { };
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        if ! blkid -o export ${config.device} | grep -q '^TYPE=swap$'; then
          mkswap \
            ${toString config.extraArgs} \
            ${config.device}
        fi
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = {
        fs.${config.device} = ''
          if ! swapon --show | grep -q "^$(readlink -f ${config.device}) "; then
            swapon ${config.device}
          fi
        '';
      };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = [{
        swapDevices = [{
          device = config.device;
          randomEncryption = config.randomEncryption;
        }];
        boot.resumeDevice = lib.mkIf config.resumeDevice config.device;
      }];
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ pkgs.gnugrep pkgs.util-linux ];
      description = "Packages";
    };
  };
}
