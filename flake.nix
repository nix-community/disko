{
  description = "Disko - declarative disk partitioning";

  # FIXME: in future we don't want lock here to give precedence to a USB live-installer's registry,
  # but garnix currently does not allow this.
  #inputs.nixpkgs.url = "nixpkgs";
  #inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.nixpkgs.url = "github:zolfariot/nixpkgs/zolfa/initrd_clevis_luks";

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
      nixosModules.default = self.nixosModules.disko; # convention
      nixosModules.disko = import ./module.nix;
      lib = import ./lib {
        inherit (nixpkgs) lib;
      };
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          disko = pkgs.callPackage ./package.nix { };
          default = self.packages.${system}.disko;
        } // pkgs.lib.optionalAttrs (!pkgs.buildPlatform.isRiscV64) {
          disko-doc = pkgs.callPackage ./doc.nix { };
        });
      # TODO: disable bios-related tests on aarch64...
      # Run checks: nix flake check -L
      checks = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # FIXME: aarch64-linux seems to hang on boot
          nixosTests = nixpkgs.lib.optionalAttrs pkgs.hostPlatform.isx86_64 (import ./tests {
            inherit pkgs;
            makeTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
            eval-config = import (pkgs.path + "/nixos/lib/eval-config.nix");
          });
          shellcheck = pkgs.runCommand "shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
            cd ${./.}
            shellcheck disk-deactivate/disk-deactivate disko
            touch $out
          '';
        in
        # FIXME: aarch64-linux seems to hang on boot
        nixpkgs.lib.optionalAttrs pkgs.hostPlatform.isx86_64 nixosTests //
        pkgs.lib.optionalAttrs (!pkgs.buildPlatform.isRiscV64 && !pkgs.hostPlatform.isx86_32) { inherit shellcheck; });
      formatter = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.writeShellApplication {
          name = "format";
          runtimeInputs = with pkgs; [
            nixpkgs-fmt
            deno
            deadnix
          ];
          text = ''
            set -o xtrace
            nixpkgs-fmt "$@"
            deno fmt "$@"
            deadnix --edit "$@"
          '';
        }
      );
    };
}
