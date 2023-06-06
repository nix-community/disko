{ makeTest ? import <nixpkgs/nixos/tests/make-test-python.nix>
, eval-config ? import <nixpkgs/nixos/lib/eval-config.nix>
, pkgs ? (import <nixpkgs> { })
}:
let
  lib = pkgs.lib;
  makeDiskoTest = (pkgs.callPackage ./lib.nix { inherit makeTest eval-config; }).makeDiskoTest;

  allTestFilenames =
    builtins.map (lib.removeSuffix ".nix") (
      builtins.filter
        (x: lib.hasSuffix ".nix" x && x != "default.nix" && x != "lib.nix")
        (lib.attrNames (builtins.readDir ./.))
    );

  allTests = lib.genAttrs allTestFilenames (test: import (./. + "/${test}.nix") { inherit makeDiskoTest pkgs; }) // {
    standalone = (pkgs.nixos [ ../example/stand-alone/configuration.nix ]).config.system.build.toplevel;
  };
in
allTests
