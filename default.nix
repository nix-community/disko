{ lib ? (import <nixpkgs> {}).lib }: {
  inherit (import ./lib {
    inherit lib;
  }) config create mount;
}
