{ config, lib, pkgs, ... }:
let
  types = import ./types.nix { inherit lib; };
  cfg = config.disko;
in {
  options.disko = {
    devices = lib.mkOption {
      type = types.devices;
    };
    enableConfig = lib.mkOption {
      description = ''
        configure nixos with the specified devices
        should be true if the system is booted with those devices
        should be false on an installer image etc.
      '';
      type = lib.types.bool;
      default = true;
    };
    addScripts = lib.mkOption {
      description = ''
        add disko-create and disko-mount scripts to systemPackages.
      '';
      type = lib.types.bool;
      default = true;
    };
  };
  config = {
    environment.systemPackages = (lib.optionals cfg.addScripts [
      (pkgs.writers.writeDashBin "disko-create" ''
        export PATH=${lib.makeBinPath (types.diskoLib.packages cfg.devices pkgs)}
        ${types.diskoLib.create cfg.devices}
      '')
      (pkgs.writers.writeDashBin "disko-mount" ''
        export PATH=${lib.makeBinPath (types.diskoLib.packages cfg.devices pkgs)}
        ${types.diskoLib.mount cfg.devices}
      '')
    ]) ++ lib.optionals cfg.enableConfig (types.diskoLib.packages cfg.devices pkgs);

    system.build.formatScript = pkgs.writers.writeDash "disko-create" ''
      export PATH=${lib.makeBinPath (types.diskoLib.packages cfg.devices pkgs)}
      ${types.diskoLib.create cfg.devices}
    '';

    system.build.mountScript = pkgs.writers.writeDash "disko-mount" ''
      export PATH=${lib.makeBinPath (types.diskoLib.packages cfg.devices pkgs)}
      ${types.diskoLib.mount cfg.devices}
    '';

    system.build.disko = pkgs.writers.writeBash "disko" ''
      export PATH=${lib.makeBinPath (types.diskoLib.packages cfg.devices pkgs)}
      ${types.diskoLib.zapCreateMount cfg.devices}
    '';

    # Remember to add config keys here if they are added to types
    fileSystems = lib.mkIf cfg.enableConfig (lib.mkMerge (lib.catAttrs "fileSystems" (types.diskoLib.config cfg.devices)));
    boot = lib.mkIf cfg.enableConfig (lib.mkMerge (lib.catAttrs "boot" (types.diskoLib.config cfg.devices)));
  };
}
