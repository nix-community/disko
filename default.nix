{ lib ? import <nixpkgs/lib>
, rootMountPoint ? "/mnt"
, checked ? false
, diskoLib ? import ./lib { inherit lib rootMountPoint; }
}:
let
  eval = cfg: lib.evalModules {
    modules = lib.singleton {
      # _file = toString input;
      imports = lib.singleton { disko.devices = cfg.disko.devices; };
      options = {
        disko.devices = lib.mkOption {
          type = diskoLib.toplevel;
        };
      };
    };
  };
in
{
  lib = lib.warn "the .lib.lib output is deprecated" diskoLib;

  _cliDestroy = cfg: pkgs: ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).destroy;
  _cliDestroyNoDeps = cfg: pkgs: ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).destroyNoDeps;

  _cliFormat = cfg: pkgs: ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).format;
  _cliFormatNoDeps = cfg: pkgs: ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).formatNoDeps;

  _cliMount = cfg: pkgs: ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).mount;
  _cliMountNoDeps = cfg: pkgs: ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).mountNoDeps;

  _cliFormatMount = cfg: pkgs: ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).formatMount;
  _cliFormatMountNoDeps = cfg: pkgs: ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).formatMountNoDeps;

  _cliDestroyFormatMount = cfg: pkgs: ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).destroyFormatMount;
  _cliDestroyFormatMountNoDeps = cfg: pkgs: ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).destroyFormatMountNoDeps;

  # legacy aliases
  create = cfg: builtins.trace "the create output is deprecated, use format instead" (eval cfg).config.disko.devices._create;
  createScript = cfg: pkgs: builtins.trace "the create output is deprecated, use format instead" ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).formatScript;
  createScriptNoDeps = cfg: pkgs: builtins.trace "the create output is deprecated, use format instead" ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).formatScriptNoDeps;

  format = cfg: (eval cfg).config.disko.devices._create;
  formatScript = cfg: pkgs: ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).formatScript;
  formatScriptNoDeps = cfg: pkgs: ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).formatScriptNoDeps;

  mount = cfg: (eval cfg).config.disko.devices._mount;
  mountScript = cfg: pkgs: ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).mountScript;
  mountScriptNoDeps = cfg: pkgs: ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).mountScriptNoDeps;

  disko = cfg: (eval cfg).config.disko.devices._disko;
  diskoScript = cfg: pkgs: ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).diskoScript;
  diskoScriptNoDeps = cfg: pkgs: ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).diskoScriptNoDeps;

  # we keep this old output for backwards compatibility
  diskoNoDeps = cfg: pkgs: builtins.trace "the diskoNoDeps output is deprecated, please use disko instead" ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).diskoScriptNoDeps;

  config = cfg: (eval cfg).config.disko.devices._config;
  packages = cfg: (eval cfg).config.disko.devices._packages;
}
