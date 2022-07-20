{
  description = "nix-powered automatic disk partitioning";

  outputs = { self, nixpkgs, flake-utils, ... }:
    {
      overlays.default = import (./. + "/overlay.nix");
    }
    // flake-utils.lib.eachSystem ["x86_64-linux"] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };
      in rec {
        lib = import ./. {inherit pkgs;};
        packages.env = pkgs.disko.env;
        checks.test = import (./. + "/tests/test.nix")
          {inherit nixpkgs; diskoLib = lib;}
          {inherit pkgs system;};
      }
    );
}
