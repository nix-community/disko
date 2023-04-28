{
  description = "Disko - declarative disk partitioning";

  # FIXME: in future we don't want lock here to give precedence to a USB live-installer's registry,
  # but garnix currently does not allow this.
  #inputs.nixpkgs.url = "nixpkgs";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "i686-linux"
        "aarch64-linux"
        "riscv64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      nixosModules.disko = import ./module.nix;
      lib = import ./. {
        inherit (nixpkgs) lib;
      };
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          disko = pkgs.callPackage ./package.nix { };
          disko-doc = pkgs.callPackage ./doc.nix { };
          default = self.packages.${system}.disko;
          # The way bcachefs support is maintained in nixpkgs is prone to breakage.
          # That's why we need to maintain a fork here:
          # https://github.com/NixOS/nixpkgs/issues/212086
          linux-bcachefs = pkgs.callPackage ./linux-testing-bcachefs.nix { };
        });
      legacyPackages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          linuxPackages_bcachefs = pkgs.linuxPackagesFor self.packages.${pkgs.system}.linux-bcachefs;
        });
      # TODO: disable bios-related tests on aarch64...
      # Run checks: nix flake check -L
      checks = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          nixosTests = import ./tests {
            inherit pkgs;
            makeTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
            eval-config = import (pkgs.path + "/nixos/lib/eval-config.nix");
          };
          shellcheck = pkgs.runCommand "shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
            cd ${./.}
            shellcheck disk-deactivate/disk-deactivate disko
            touch $out
          '';
        in
        nixosTests // { inherit shellcheck; });
      formatter = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.writeShellApplication {
          name = "normalise_nix";
          runtimeInputs = with pkgs; [
            nixpkgs-fmt
            statix
          ];
          text = ''
            set -o xtrace
            nixpkgs-fmt "$@"
            statix fix "$@"
          '';
        }
      );
    };
}
