{ diskoLib, config, options, lib, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "swap" ];
      internal = true;
      description = "Type";
    };
    randomEncryption = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to randomly encrypt the swap";
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = dev: { };
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = { dev }: ''
        mkswap ${dev}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { dev }: {
        fs.${dev} = ''
          if ! swapon --show | grep -q '^${dev} '; then
            swapon ${dev}
          fi
        '';
      };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = dev: [{
        swapDevices = [{
          device = dev;
          randomEncryption = config.randomEncryption;
        }];
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
