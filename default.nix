{ lib ? import <nixpkgs/lib>
, rootMountPoint ? "/mnt"
, checked ? false
}:
let
  types = import ./types { inherit lib rootMountPoint; };
  eval = cfg: lib.evalModules {
    modules = lib.singleton {
      # _file = toString input;
      imports = lib.singleton { disko.devices = cfg.disko.devices; };
      options = {
        disko.devices = lib.mkOption {
          type = types.devices;
        };
      };
    };
  };
in
{
  types = types;
  create = cfg: types.diskoLib.create (eval cfg).config.disko.devices;
  createScript = cfg: pkgs: (types.diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko-create" ''
    export PATH=${lib.makeBinPath (types.diskoLib.packages (eval cfg).config.disko.devices pkgs)}:$PATH
    ${types.diskoLib.create (eval cfg).config.disko.devices}
  '';
  createScriptNoDeps = cfg: pkgs: (types.diskoLib.writeCheckedBash { inherit pkgs checked; noDeps = true; }) "disko-create" ''
    ${types.diskoLib.create (eval cfg).config.disko.devices}
  '';
  mount = cfg: types.diskoLib.mount (eval cfg).config.disko.devices;
  mountScript = cfg: pkgs: (types.diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko-mount" ''
    export PATH=${lib.makeBinPath (types.diskoLib.packages (eval cfg).config.disko.devices pkgs)}:$PATH
    ${types.diskoLib.mount (eval cfg).config.disko.devices}
  '';
  mountScriptNoDeps = cfg: pkgs: (types.diskoLib.writeCheckedBash { inherit pkgs checked; noDeps = true; }) "disko-mount" ''
    ${types.diskoLib.mount (eval cfg).config.disko.devices}
  '';
  zapCreateMount = cfg: types.diskoLib.zapCreateMount (eval cfg).config.disko.devices;
  zapCreateMountScript = cfg: pkgs: (types.diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko-zap-create-mount" ''
    export PATH=${lib.makeBinPath (types.diskoLib.packages (eval cfg).config.disko.devices pkgs)}:$PATH
    ${types.diskoLib.zapCreateMount (eval cfg).config.disko.devices}
  '';
  zapCreateMountScriptNoDeps = cfg: pkgs: (types.diskoLib.writeCheckedBash { inherit pkgs checked; noDeps = true; }) "disko-zap-create-mount" ''
    ${types.diskoLib.zapCreateMount (eval cfg).config.disko.devices}
  '';
  config = cfg: { imports = types.diskoLib.config (eval cfg).config.disko.devices; };
  packages = cfg: types.diskoLib.packages (eval cfg).config.disko.devices;
}
