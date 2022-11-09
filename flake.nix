{
  description = "Description for the project";

  # don't lock to give precedence to a USB live-installer's registry
  inputs.nixpkgs.url = "nixpkgs";

  outputs = { self, nixpkgs, ... }: {
    nixosModules.disko = import ./module.nix;
    lib = import ./. {
      inherit (nixpkgs) lib;
    };
    packages.x86_64-linux.disko = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      inherit (pkgs) lib;
      inclFiles = {src, name}: files: lib.cleanSourceWith {
        inherit src name;
        filter = _path: _type: _type == "regular"
          && lib.any (file: builtins.baseNameOf _path == file) files;
      };
    in derivation rec{
      system = "x86_64-linux";
      name = "disko";
      builder = "/bin/sh";
      PATH    = "${pkgs.coreutils}/bin:${pkgs.gnused}/bin";
      passAsFile = ["buildPhase"];
      buildPhase = ''
        mkdir -p $out/bin $out/share/disko
	cp -r $src/* $out/share/disko
	sed \
	  -e "s|libexec_dir=\".*\"|libexec_dir=\"$out/share/disko\"|" \
	  -e "s|#!/usr/bin/env.*|#!/usr/bin/env bash|" \
	  $src/disko > $out/bin/disko
	chmod 755 $out/bin/disko
      '';
      args = ["-c" ". $buildPhasePath"];
      src = inclFiles { inherit name; src = ./.; } [
        "disko"
        "cli.nix"
        "default.nix"
        "types.nix"
        "options.nix"
      ];
    } // {
      meta.description = "Format disks with nix-config";
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
