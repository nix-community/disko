{
  flake,
  flakeAttr,
  diskMappings,
  extraSystemConfig ? "{}",
  writeEfiBootEntries ? false,
  rootMountPoint ? "/mnt",
}:
let
  originalSystem = (builtins.getFlake "${flake}").nixosConfigurations."${flakeAttr}";
  lib = originalSystem.pkgs.lib;

  # Apply extraSystemConfig first, before accessing any config values
  baseSystem = originalSystem.extendModules {
    modules = [
      ({ _file = "disko-install --system-config"; } // (builtins.fromJSON extraSystemConfig))
    ];
  };

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
  ) baseSystem.config.disko.devices.disk;

  # filter all nixos module internal attributes
  cleanedDisks = lib.filterAttrsRecursive (n: _: !lib.hasPrefix "_" n) modifiedDisks;

  diskoSystem = baseSystem.extendModules {
    modules = [
      {
        disko.rootMountPoint = rootMountPoint;
        disko.devices.disk = lib.mkVMOverride cleanedDisks;
      }
    ];
  };

  installSystem = baseSystem.extendModules {
    modules = [
      {
        boot.loader.efi.canTouchEfiVariables = lib.mkVMOverride writeEfiBootEntries;
        boot.loader.grub.devices = lib.mkVMOverride (lib.attrValues diskMappings);
      }
    ];
  };
in
{
  installToplevel = installSystem.config.system.build.toplevel;
  closureInfo = installSystem.pkgs.closureInfo {
    rootPaths = [ installSystem.config.system.build.toplevel ];
  };
  inherit (diskoSystem.config.system.build) formatScript mountScript diskoScript;
}
