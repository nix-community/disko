{
  makeTest ? import <nixpkgs/nixos/tests/make-test-python.nix>,
  eval-config ? import <nixpkgs/nixos/lib/eval-config.nix>,
  pkgs ? import <nixpkgs> { },
}:
let
  lib = pkgs.lib;
  diskoLib = import ../lib { inherit lib makeTest eval-config; };

  allTestFilenames = builtins.map (lib.removeSuffix ".nix") (
    builtins.filter (x: lib.hasSuffix ".nix" x && x != "default.nix") (
      lib.attrNames (builtins.readDir ./.)
    )
  );
  incompatibleTests = lib.optionals pkgs.stdenv.buildPlatform.isRiscV64 [
    "zfs"
    "zfs-over-legacy"
    "cli"
    "module"
    "complex"
  ];
  allCompatibleFilenames = lib.subtractLists incompatibleTests allTestFilenames;

  allTests = lib.genAttrs allCompatibleFilenames (
    test: import (./. + "/${test}.nix") { inherit diskoLib pkgs; }
  );
in
allTests
