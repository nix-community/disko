{
  flake,
  flakeAttr,
  diskMappings,
  extraSystemConfig ? "{}",
  writeEfiBootEntries ? false,
  rootMountPoint ? "/mnt",
  hostSystem ? builtins.currentSystem, # the system running the format script, for cross-compilation
}:
let
  originalSystem = (builtins.getFlake "${flake}").nixosConfigurations."${flakeAttr}";
  lib = originalSystem.pkgs.lib;

  # Get host pkgs for cross-compilation (format scripts need host-native tools)
  hostPkgs = import originalSystem.pkgs.path { system = hostSystem; };

  deviceName =
    name:
    if diskMappings ? ${name} then
      diskMappings.${name}
    else
      throw "No device passed for disk '${name}'. Pass `--disk ${name} /dev/name` via commandline";

  modifiedDisks = builtins.mapAttrs (
    name: value:
    let
      dev = deviceName name;
    in
    value
    // {
      device = dev;
      content = value.content // {
        device = dev;
      };
    }
  ) originalSystem.config.disko.devices.disk;

  # filter all nixos module internal attributes
  cleanedDisks = lib.filterAttrsRecursive (n: _: !lib.hasPrefix "_" n) modifiedDisks;

  diskoSystem = originalSystem.extendModules {
    modules = [
      {
        disko.rootMountPoint = rootMountPoint;
        disko.devices.disk = lib.mkVMOverride cleanedDisks;
      }
    ];
  };

  installSystem = originalSystem.extendModules {
    modules = [
      (
        { lib, ... }:
        {
          boot.loader.efi.canTouchEfiVariables = lib.mkVMOverride writeEfiBootEntries;
          boot.loader.grub.devices = lib.mkVMOverride (lib.attrValues diskMappings);
          imports = [
            ({ _file = "disko-install --system-config"; } // (builtins.fromJSON extraSystemConfig))
          ];
        }
      )
    ];
  };
  # Build scripts with hostPkgs for format/destroy, targetPkgs for mount
  # This enables cross-compilation: format scripts use host-native tools
  # that can communicate with the running kernel
  scripts = diskoSystem.config.disko.devices._scripts {
    pkgs = diskoSystem.pkgs; # target pkgs for mount scripts
    inherit hostPkgs; # host pkgs for format/destroy scripts
  };
in
{
  installToplevel = installSystem.config.system.build.toplevel;
  closureInfo = installSystem.pkgs.closureInfo {
    rootPaths = [ installSystem.config.system.build.toplevel ];
  };
  # Use scripts built with hostPkgs for cross-compilation support
  inherit (scripts) formatScript mountScript diskoScript;
}
