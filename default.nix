{ lib ? import <nixpkgs/lib>
, pkgs ? import <nixpkgs> {}
}:
let
  types = import ./types.nix { inherit lib pkgs; };
  eval = cfg: lib.evalModules {
    modules = lib.singleton {
      # _file = toString input;
      imports = lib.singleton { topLevel.devices = cfg; };
      options = {
        topLevel = lib.mkOption {
          type = types.topLevel;
        };
      };
    };
  };
in {
  types = types;
  create = cfg: (eval cfg).config.topLevel.create;
  mount = cfg: (eval cfg).config.topLevel.mount;
  config = cfg: (eval cfg).config.topLevel.config;
}
