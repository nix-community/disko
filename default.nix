{ lib ? import <nixpkgs/lib>
, rootMountPoint ? "/mnt"
, checked ? false
}:
let
  diskoLib = import ./lib { inherit lib rootMountPoint; };
  eval = cfg: lib.evalModules {
    modules = lib.singleton {
      # _file = toString input;
      imports = lib.singleton { disko.devices = cfg.disko.devices; };
      options = {
        disko.devices = lib.mkOption {
          type = diskoLib.devices;
        };
      };
    };
  };
in
{
  lib = diskoLib;
  create = cfg: diskoLib.create (eval cfg).config.disko.devices;
  createScript = cfg: pkgs: (diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko-create" ''
    export PATH=${lib.makeBinPath (diskoLib.packages (eval cfg).config.disko.devices pkgs)}:$PATH
    ${diskoLib.create (eval cfg).config.disko.devices}
  '';
  createScriptNoDeps = cfg: pkgs: (diskoLib.writeCheckedBash { inherit pkgs checked; noDeps = true; }) "disko-create" ''
    ${diskoLib.create (eval cfg).config.disko.devices}
  '';
  mount = cfg: diskoLib.mount (eval cfg).config.disko.devices;
  mountScript = cfg: pkgs: (diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko-mount" ''
    export PATH=${lib.makeBinPath (diskoLib.packages (eval cfg).config.disko.devices pkgs)}:$PATH
    ${diskoLib.mount (eval cfg).config.disko.devices}
  '';
  mountScriptNoDeps = cfg: pkgs: (diskoLib.writeCheckedBash { inherit pkgs checked; noDeps = true; }) "disko-mount" ''
    ${diskoLib.mount (eval cfg).config.disko.devices}
  '';
  disko = cfg: diskoLib.zapCreateMount (eval cfg).config.disko.devices;
  diskoScript = cfg: pkgs: (diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko-zap-create-mount" ''
    export PATH=${lib.makeBinPath (diskoLib.packages (eval cfg).config.disko.devices pkgs)}:$PATH
    ${diskoLib.zapCreateMount (eval cfg).config.disko.devices}
  '';
  diskoNoDeps = cfg: pkgs: (diskoLib.writeCheckedBash { inherit pkgs checked; noDeps = true; }) "disko-zap-create-mount" ''
    ${diskoLib.zapCreateMount (eval cfg).config.disko.devices}
  '';
  config = cfg: { imports = diskoLib.config (eval cfg).config.disko.devices; };
  packages = cfg: diskoLib.packages (eval cfg).config.disko.devices;
}
