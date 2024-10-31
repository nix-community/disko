{ makeTest ? import <nixpkgs/nixos/tests/make-test-python.nix>
, eval-config ? import <nixpkgs/nixos/lib/eval-config.nix>
, pkgs ? import <nixpkgs> { }
}:
let
  lib = pkgs.lib;
  fs = lib.fileset;
  diskoLib = import ../src/disko_lib { inherit lib makeTest eval-config; };

  incompatibleTests = lib.optionals pkgs.buildPlatform.isRiscV64 [ "zfs" "zfs-over-legacy" "cli" "module" "complex" ];

  allTestFilenames =
    (fs.toList
      (fs.difference
        (fs.fileFilter
          ({ name, hasExt, ... }:
            hasExt "nix"
            && name != "default.nix"
            && !(lib.elem (lib.removeSuffix ".nix" name) incompatibleTests))
          ./.)
        (fs.fileFilter ({ ... }: true) ./disko-install))
    );

  allTests = lib.listToAttrs (lib.map
    (test: {
      name = lib.removeSuffix ".nix" (builtins.baseNameOf test);
      value = import test { inherit diskoLib pkgs; };
    })
    allTestFilenames);
in
allTests
