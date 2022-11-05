{ lib ? import <nixpkgs/lib> }: let
  types = import ./types.nix { inherit lib; };
in {
  devices = lib.mkOption {
    type = types.devices;
  };
}
