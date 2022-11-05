{ lib ? import <nixpkgs/lib> }:
let
  types = import ./types.nix { inherit lib; };
  options = import ./options.nix { inherit lib; };
  eval = cfg: lib.evalModules {
    modules = lib.singleton {
      # _file = toString input;
      imports = lib.singleton { devices = cfg; };
      inherit options;
    };
  };
in {
  types = types;
  create = cfg: types.diskoLib.create (eval cfg).config.devices;
  createScript = cfg: pkgs: pkgs.writeScript "disko-create" ''
    export PATH=${lib.makeBinPath (types.diskoLib.packages (eval cfg).config.devices pkgs)}
    ${types.diskoLib.create (eval cfg).config.devices}
  '';
  mount = cfg: types.diskoLib.mount (eval cfg).config.devices;
  mountScript = cfg: pkgs: pkgs.writeScript "disko-mount" ''
    export PATH=${lib.makeBinPath (types.diskoLib.packages (eval cfg).config.devices pkgs)}
    ${types.diskoLib.mount (eval cfg).config.devices}
  '';
  config = cfg: { imports = types.diskoLib.config (eval cfg).config.devices; };
  packages = cfg: types.diskoLib.packages (eval cfg).config.devices;
}
