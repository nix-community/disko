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
  pkgs = originalSystem.pkgs;
  lib = pkgs.lib;

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

  installSystemDataFile = pkgs.writeText "installSystemData.json" (
    builtins.toJSON {
      inherit
        flake
        flakeAttr
        diskMappings
        extraSystemConfig
        writeEfiBootEntries
        ;
    }
  );

  # We need to yield a Nix file for the modified installSystem to avoid
  # building it on the Nix store of the running system (which may be
  # space-limited) and instead defer building to nixos-install (which will
  # build on the Nix store of the install target).
  installSystemFile = pkgs.writeText "install-system.nix" /* nix */ ''
    import ${./lib/make-install-system.nix} (builtins.fromJSON (builtins.readFile "${installSystemDataFile}"))
  '';
in
{
  inherit installSystemFile;
  inherit (diskoSystem.config.system.build) formatScript mountScript diskoScript;
}
