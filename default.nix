{
  lib ? pkgs.lib,
  pkgs ? import <nixpkgs> {overlays = [(import ./overlay.nix)];},
  diskoEnv ? pkgs.diskoEnv,
  ...
}:
import ./lib { inherit lib diskoEnv; }