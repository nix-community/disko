{
  config,
  lib,
  extendModules,
  modulesPath,
  ...
}:

let
  diskoLib = import ./lib {
    inherit lib;
    rootMountPoint = config.disko.rootMountPoint;
  };
in
{
  options.flake.diskoConfigurations = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        imports = [
          ./module.nix
          {
            # `modulesPath` and `extendedModules` are probably not needed here.
            # its only here to test if virtualisation.vmVariantWithDisko would get properly typed
            # but alas it does not.
            inherit diskoLib extendModules modulesPath;
          }

          # Minimal stub to satisfy basic module requirements if pkgs/config are used
          { _module.check = false; }
        ];
      }
    );
    default = { };
    description = "Instantiated Disko configurations. Used by `disko` and `disko-install`.";
    example = {
      my-pc = {
        disko.devices = {
          disk = {
            my-disk = {
              device = "/dev/sda";
              type = "disk";
              content = {
                type = "gpt";
                partitions = {
                  ESP = {
                    type = "EF00";
                    size = "500M";
                    content = {
                      type = "filesystem";
                      format = "vfat";
                      mountpoint = "/boot";
                      mountOptions = [ "umask=0077" ];
                    };
                  };
                  root = {
                    size = "100%";
                    content = {
                      type = "filesystem";
                      format = "ext4";
                      mountpoint = "/";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
