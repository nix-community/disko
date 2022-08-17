{
  description = "Description for the project";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }: {
    lib = import ./. {
      inherit (nixpkgs) lib;
    };
    checks.x86_64-linux = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      # Run tests: nix flake check -L
      nixos-test = pkgs.callPackage ./tests/test.nix {
        makeTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
      };
    };
  };
}
