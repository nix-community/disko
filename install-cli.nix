{ flake
, flakeAttr
, diskMappings
, writeEfiBootEntries ? false
, rootMountPoint ? "/mnt"
}:
let
  originalSystem = (builtins.getFlake "${flake}").nixosConfigurations."${flakeAttr}";
  diskoSystem =
    let
      lib = originalSystem.lib;

      modifiedDisks = builtins.mapAttrs
        (name: value: let
          dev = if  diskMappings ? ${name} then
            diskMappings.${name}
          else
            throw "No device passed for disk '${name}'. Pass `--disk ${name} /dev/name` via commandline";
        in value // {
          device = dev;
          content = value.content // { device = dev; };
        })
        originalSystem.config.disko.devices.disk;

      cleanedDisks = lib.filterAttrsRecursive (n: _: !lib.hasPrefix "_" n) modifiedDisks;
    in
    originalSystem.extendModules {
      modules = [{
        disko.rootMountPoint = rootMountPoint;
        disko.devices.disk = lib.mkVMOverride cleanedDisks;
      }];
    };
   installSystem = originalSystem.extendModules {
     modules = [({ lib, ... }: {
       boot.loader.efi.canTouchEfiVariables = lib.mkVMOverride writeEfiBootEntries;
       boot.loader.grub.devices = lib.mkVMOverride diskoSystem.config.boot.loader.grub.devices;
     })];
   };
in
{
  installToplevel = installSystem.config.system.build.toplevel;
  inherit (diskoSystem.config.system.build) formatScript mountScript diskoScript;
}
