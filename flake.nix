{
  description = "Disko - declarative disk partitioning";

  # FIXME: in future we don't want lock here to give precedence to a USB live-installer's registry,
  # but garnix currently does not allow this.
  #inputs.nixpkgs.url = "nixpkgs";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs, ... }: let
    supportedSystems = [
      "x86_64-linux"
      "i686-linux"
      "aarch64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
  in {
    nixosModules.disko = import ./module.nix;
    lib = import ./. {
      inherit (nixpkgs) lib;
    };
    packages = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      disko = pkgs.callPackage ./package.nix {};
      default = self.packages.${system}.disko;
    });
    # TODO: disable bios-related tests on aarch64...
    # Run checks: nix flake check -L
    checks = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
      nixosTests = import ./tests {
        inherit pkgs;
        makeTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
        eval-config = import (pkgs.path + "/nixos/lib/eval-config.nix");
      };
      documentation = (import (pkgs.path + "/nixos/doc/manual") rec {
        inherit pkgs;
        config = lib.evalModules {
          modules = [
            { inherit (import ./module.nix { inherit config lib pkgs; }) options; }
          ];
        };
        version = self.rev or "dirty";
        revision = version;
        options = config.options;
        allowDocBook = true;
        prefix = ./.;
      }).optionsJSON;
      shellcheck = pkgs.runCommand "shellcheck" { nativeBuildInputs =  [ pkgs.shellcheck ]; } ''
        cd ${./.}
        shellcheck disk-deactivate/disk-deactivate disko
        touch $out
      '';
    in
      nixosTests // { inherit documentation shellcheck; });
  };
}
