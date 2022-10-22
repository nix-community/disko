{ lib ? import <nixpkgs/lib> }:
let
  types = import ./types.nix { inherit lib; };
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
in {
  types = types;
  create = cfg: types.diskoLib.create (eval cfg).config.devices;
  mount = cfg: types.diskoLib.mount (eval cfg).config.devices;
  config = cfg: types.diskoLib.config (eval cfg).config.devices;
  packages = cfg: types.diskoLib.packages (eval cfg).config.devices;
}
