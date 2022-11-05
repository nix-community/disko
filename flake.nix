{
  description = "Description for the project";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }: {
    nixosModules.disko = import ./module.nix;
    lib = import ./. {
      inherit (nixpkgs) lib;
    };
    packages.x86_64-linux.disko = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in pkgs.stdenv.mkDerivation {
      name = "disko";
      src = ./.;
      meta.description = "Format disks with nix-config";
      installFlags = [ "PREFIX=$(out)" ];
    };
    packages.x86_64-linux.default = self.packages.x86_64-linux.disko;
    checks.x86_64-linux = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
      # Run tests: nix flake check -L
      import ./tests {
        inherit pkgs;
        makeTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
        eval-config = import (pkgs.path + "/nixos/lib/eval-config.nix");
      };
  };
}
