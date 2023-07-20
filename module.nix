{ config, lib, pkgs, extendModules, ... }@args:
let
  diskoLib = import ./lib {
    inherit lib;
    rootMountPoint = config.disko.rootMountPoint;
  };
  cfg = config.disko;
in
{
  options.disko = {
    devices = lib.mkOption {
      type = diskoLib.toplevel;
      default = { };
      description = "The devices to set up";
    };
    rootMountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/mnt";
      description = "Where the device tree should be mounted by the mountScript";
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
    checkScripts = lib.mkOption {
      description = ''
        Whether to run shellcheck on script outputs
      '';
      type = lib.types.bool;
      default = false;
    };
    tests = {
      efi = lib.mkOption {
        description = ''
          Whether efi is enabled for the `system.build.installTest`.
          We try to automatically detect efi based on the configured bootloader.
        '';
        type = lib.types.bool;
        default = config.boot.loader.systemd-boot.enable || config.boot.loader.grub.efiSupport;
      };
    };
  };
  config = lib.mkIf (cfg.devices.disk != { }) {
    system.build = (cfg.devices._scripts { inherit pkgs; checked = cfg.checkScripts; }) // {

      # we keep this old outputs for compatibility
      disko = builtins.trace "the .disko output is deprecated, plase use .diskoScript instead" cfg.devices._scripts.diskoScript;
      diskoNoDeps = builtins.trace "the .diskoNoDeps output is deprecated, plase use .diskoScriptNoDeps instead" cfg.devices._scripts.diskoScriptNoDeps;

      installTest = diskoLib.testLib.makeDiskoTest {
        inherit extendModules pkgs;
        name = "${config.networking.hostName}-disko";
        disko-config = builtins.removeAttrs config ["_module"];
        testMode = "direct";
        efi = cfg.tests.efi;
      };
    };


    # we need to specify the keys here, so we don't get an infinite recursion error
    # Remember to add config keys here if they are added to types
    fileSystems = lib.mkIf cfg.enableConfig cfg.devices._config.fileSystems or {};
    boot = lib.mkIf cfg.enableConfig cfg.devices._config.boot or {};
    swapDevices = lib.mkIf cfg.enableConfig cfg.devices._config.swapDevices or [];
  };
}
