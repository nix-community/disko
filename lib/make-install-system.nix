{
  flake,
  flakeAttr,
  diskMappings,
  extraSystemConfig,
  writeEfiBootEntries,
}:

let
  originalSystem = (builtins.getFlake "${flake}").nixosConfigurations."${flakeAttr}";
in
originalSystem.extendModules {
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
}
