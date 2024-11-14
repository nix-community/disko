{
  description = "Disko - declarative disk partitioning";

  # FIXME: in future we don't want lock here to give precedence to a USB live-installer's registry,
  # but garnix currently does not allow this.
  #inputs.nixpkgs.url = "nixpkgs";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      supportedSystems = [
        "x86_64-linux"
        "i686-linux"
        "aarch64-linux"
        "riscv64-linux"
      ];
      forAllSystems = lib.genAttrs supportedSystems;

      versionInfo = import ./version.nix;
      version = versionInfo.version + (lib.optionalString (!versionInfo.released) "-dirty");

      diskoLib = import ./src/disko_lib {
        inherit (nixpkgs) lib;
      };
    in
    {
      lib = diskoLib;
      nixosModules.default = self.nixosModules.disko; # convention
      nixosModules.disko.imports = [ ./module.nix ];
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          disko = pkgs.callPackage ./package.nix { diskoVersion = version; };
          disko2 = pkgs.callPackage ./package-disko2.nix { diskoVersion = version; };
          # alias to make `nix run` more convenient
          disko-install = self.packages.${system}.disko.overrideAttrs (_old: {
            name = "disko-install";
          });
          default = self.packages.${system}.disko;

          create-release = pkgs.callPackage ./scripts/create-release.nix { };
        } // pkgs.lib.optionalAttrs (!pkgs.buildPlatform.isRiscV64) {
          disko-doc = pkgs.callPackage ./doc.nix { };
        });
      # TODO: disable bios-related tests on aarch64...
      # Run checks: nix flake check -L
      checks = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # FIXME: aarch64-linux seems to hang on boot
          nixosTests = lib.optionalAttrs pkgs.hostPlatform.isx86_64 (import ./tests {
            inherit pkgs;
            makeTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
            eval-config = import (pkgs.path + "/nixos/lib/eval-config.nix");
          });

          disko-install = pkgs.callPackage ./tests/disko-install {
            inherit self;
            diskoVersion = version;
          };

          # TODO: Add a CI pipeline instead that runs nix run .#pytest inside nix develop
          pytest-ci-only = pkgs.runCommand "pytest" { nativeBuildInputs = [ pkgs.python3Packages.pytest ]; } ''
            cd ${./.}
            # eval_config runs nix, which is forbidden inside of nix derivations by default
            pytest -vv --doctest-modules -p no:cacheprovider --ignore=tests/disko_lib/eval_config
            touch $out
          '';

          shellcheck = pkgs.runCommand "shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
            cd ${./.}
            shellcheck src/disk-deactivate/disk-deactivate disko disko2
            touch $out
          '';

          jsonTypes = pkgs.writeTextFile { name = "jsonTypes"; text = (builtins.toJSON diskoLib.jsonTypes); };
        in
        # FIXME: aarch64-linux seems to hang on boot
        lib.optionalAttrs pkgs.hostPlatform.isx86_64 (nixosTests // { inherit disko-install; }) //
        pkgs.lib.optionalAttrs (!pkgs.buildPlatform.isRiscV64 && !pkgs.hostPlatform.isx86_32) {
          inherit pytest-ci-only shellcheck jsonTypes;
          inherit (self.packages.${system}) disko-doc;
        });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            name = "disko-dev";
            packages = (with pkgs; [
              nixpkgs-fmt # Formatter for Nix code
              shellcheck # Linter for shell scripts
              ruff # Formatter and linter for Python
              (python3.withPackages (ps: [
                ps.mypy # Static type checker
                ps.pytest # Test runner

                # Actual runtime depedencies
                ps.pydantic # Validation of nixos configuration
              ]))
            ]);
          };
        });

      nixosConfigurations.testmachine = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./tests/disko-install/configuration.nix
          ./example/hybrid.nix
          ./module.nix
        ];
      };
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
            ruff
          ];
          text = ''
            showUsage() {
              cat <<EOF
            Usage: $0 [OPTIONS] FILES...
              -c, --check  Only check formatting, do not modify files.
              -h, --help   Show this help message.
            EOF
            }

            check=
            files=()

            parseArgs() {
              while [[ $# -gt 0 ]]; do
                case "$1" in
                -h | --help)
                  showUsage
                  exit 0
                  ;;
                -c | --check)
                  check=1
                  ;;
                *)
                  files+=("$1")
                  ;;
                esac
                shift
              done

              if [[ ''${#files[@]} -eq 0 ]]; then
                files=(.)
              fi
            }

            main() {
              parseArgs "$@"

              if [[ -z "$check" ]]; then
                set -o xtrace

                nixpkgs-fmt -- "''${files[@]}"
                deno fmt -- "''${files[@]}"
                deadnix --edit -- "''${files[@]}"
                ruff check --fix
                ruff format
              else
                set -o xtrace

                nixpkgs-fmt --check -- "''${files[@]}"
                deno fmt --check -- "''${files[@]}"
                deadnix -- "''${files[@]}"
                ruff check
                ruff format --check
              fi
            }

            main "$@"
          '';
        }
      );
    };
}
