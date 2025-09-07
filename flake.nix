{
  description = "Disko - declarative disk partitioning";

  # FIXME: in future we don't want lock here to give precedence to a USB live-installer's registry,
  # but garnix currently does not allow this.
  #inputs.nixpkgs.url = "nixpkgs";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      supportedSystems = [
        "x86_64-linux"
        "i686-linux"
        "aarch64-linux"
        "riscv64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs supportedSystems;

      versionInfo = import ./version.nix;
      version = versionInfo.version + (lib.optionalString (!versionInfo.released) "-dirty");

      diskoLib = import ./lib {
        inherit (nixpkgs) lib;
      };
    in
    {
      nixosModules.default = self.nixosModules.disko; # convention
      nixosModules.disko = ./module.nix;
      flakeModule = self.flakeModules.default;
      flakeModules.default = self.flakeModules.disko;
      flakeModules.disko = ./flake-module.nix;
      lib = diskoLib;
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          disko = pkgs.callPackage ./package.nix { diskoVersion = version; };
          # alias to make `nix run` more convenient
          disko-install = self.packages.${system}.disko.overrideAttrs (_old: {
            name = "disko-install";
          });
          default = self.packages.${system}.disko;

          create-release = pkgs.callPackage ./scripts/create-release.nix { };
        }
        // pkgs.lib.optionalAttrs (!pkgs.stdenv.buildPlatform.isRiscV64) {
          disko-doc = pkgs.callPackage ./doc.nix { };
        }
      );
      # TODO: disable bios-related tests on aarch64...
      # Run checks: nix flake check -L
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # FIXME: aarch64-linux seems to hang on boot
          nixosTests = lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 (
            import ./tests {
              inherit pkgs;
              makeTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
              eval-config = import (pkgs.path + "/nixos/lib/eval-config.nix");
            }
          );

          disko-install = pkgs.callPackage ./tests/disko-install {
            inherit self;
            diskoVersion = version;
          };

          checkJqSyntax = pkgs.runCommand "check-jq-syntax" { nativeBuildInputs = [ pkgs.jq ]; } ''
            echo '{ "blockdevices" : [] }' | jq -r -f ${./disk-deactivate/disk-deactivate.jq} --arg disk_to_clear foo
            echo '{ "blockdevices" : [] }' | jq -r -f ${./disk-deactivate/zfs-swap-deactivate.jq}
            touch $out
          '';

          jsonTypes = pkgs.writeTextFile {
            name = "jsonTypes";
            text = (builtins.toJSON diskoLib.jsonTypes);
          };

          treefmt = pkgs.runCommand "treefmt" { } ''
            ${self.formatter.${system}}/bin/treefmt --ci --working-dir ${self}
            touch $out
          '';
        in
        # FIXME: aarch64-linux seems to hang on boot
        lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 (nixosTests // { inherit disko-install; })
        //
          pkgs.lib.optionalAttrs (!pkgs.stdenv.buildPlatform.isRiscV64 && !pkgs.stdenv.hostPlatform.isx86_32)
            {
              inherit jsonTypes treefmt checkJqSyntax;
              inherit (self.packages.${system}) disko-doc;
            }
      );

      nixosConfigurations.testmachine = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./tests/disko-install/configuration.nix
          ./example/hybrid.nix
          ./module.nix
        ];
      };
      formatter = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.writeShellApplication {
          name = "treefmt";
          text = ''treefmt "$@"'';
          runtimeInputs = [
            pkgs.deadnix
            pkgs.nixfmt-rfc-style
            pkgs.shellcheck
            pkgs.treefmt
          ];
        }
      );
      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = [
            self.formatter.${system}
          ];
        };
      });
    };
}
