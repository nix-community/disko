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
  # We might instead reuse some of the deprecated output names to refer to the values the _cli* outputs currently do,
  # but this warning allows us to get feedback from users early in case they have a use case we haven't considered.
  warnDeprecated = name: lib.warn "the ${name} output is deprecated and will be removed, please open an issue if you're using it!";
in
{
  lib = warnDeprecated ".lib.lib" diskoLib;

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
  create = cfg: warnDeprecated "create" (eval cfg).config.disko.devices._create;
  createScript = cfg: pkgs: warnDeprecated "createScript" ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).formatScript;
  createScriptNoDeps = cfg: pkgs: warnDeprecated "createScriptNoDeps" ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).formatScriptNoDeps;

  format = cfg: warnDeprecated "format" (eval cfg).config.disko.devices._create;
  formatScript = cfg: pkgs: warnDeprecated "formatScript" ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).formatScript;
  formatScriptNoDeps = cfg: pkgs: warnDeprecated "formatScriptNoDeps" ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).formatScriptNoDeps;

  mount = cfg: warnDeprecated "mount" (eval cfg).config.disko.devices._mount;
  mountScript = cfg: pkgs: warnDeprecated "mountScript" ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).mountScript;
  mountScriptNoDeps = cfg: pkgs: warnDeprecated "mountScriptNoDeps" ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).mountScriptNoDeps;

  disko = cfg: warnDeprecated "disko" (eval cfg).config.disko.devices._disko;
  diskoScript = cfg: pkgs: warnDeprecated "diskoScript" ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).diskoScript;
  diskoScriptNoDeps = cfg: pkgs: warnDeprecated "diskoScriptNoDeps" ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).diskoScriptNoDeps;

  # we keep this old output for backwards compatibility
  diskoNoDeps = cfg: pkgs: warnDeprecated "diskoNoDeps" ((eval cfg).config.disko.devices._scripts { inherit pkgs checked; }).diskoScriptNoDeps;

  config = cfg: (eval cfg).config.disko.devices._config;
  packages = cfg: (eval cfg).config.disko.devices._packages;
}
