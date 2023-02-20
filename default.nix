{ lib ? import <nixpkgs/lib>
, rootMountPoint ? "/mnt"
, checked ? false
}:
let
  types = import ./types { inherit lib rootMountPoint; };
  eval = cfg: lib.evalModules {
    modules = lib.singleton {
      # _file = toString input;
      imports = lib.singleton { devices = cfg; };
      options = {
        devices = lib.mkOption {
          type = types.devices;
        };
      };
    };
  };
in
{
  types = types;
  create = cfg: types.diskoLib.create (eval cfg).config.devices;
  createScript = cfg: pkgs: (types.diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko-create" ''
    export PATH=${lib.makeBinPath (types.diskoLib.packages (eval cfg).config.devices pkgs)}:$PATH
    ${types.diskoLib.create (eval cfg).config.devices}
  '';
  createScriptNoDeps = cfg: pkgs: (types.diskoLib.writeCheckedBash { inherit pkgs checked; noDeps = true; }) "disko-create" ''
    ${types.diskoLib.create (eval cfg).config.devices}
  '';
  mount = cfg: types.diskoLib.mount (eval cfg).config.devices;
  mountScript = cfg: pkgs: (types.diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko-mount" ''
    export PATH=${lib.makeBinPath (types.diskoLib.packages (eval cfg).config.devices pkgs)}:$PATH
    ${types.diskoLib.mount (eval cfg).config.devices}
  '';
  mountScriptNoDeps = cfg: pkgs: (types.diskoLib.writeCheckedBash { inherit pkgs checked; noDeps = true; }) "disko-mount" ''
    ${types.diskoLib.mount (eval cfg).config.devices}
  '';
  zapCreateMount = cfg: types.diskoLib.zapCreateMount (eval cfg).config.devices;
  zapCreateMountScript = cfg: pkgs: (types.diskoLib.writeCheckedBash { inherit pkgs checked; }) "disko-zap-create-mount" ''
    export PATH=${lib.makeBinPath (types.diskoLib.packages (eval cfg).config.devices pkgs)}:$PATH
    ${types.diskoLib.zapCreateMount (eval cfg).config.devices}
  '';
  zapCreateMountScriptNoDeps = cfg: pkgs: (types.diskoLib.writeCheckedBash { inherit pkgs checked; noDeps = true; }) "disko-zap-create-mount" ''
    ${types.diskoLib.zapCreateMount (eval cfg).config.devices}
  '';
  config = cfg: { imports = types.diskoLib.config (eval cfg).config.devices; };
  packages = cfg: types.diskoLib.packages (eval cfg).config.devices;
}
