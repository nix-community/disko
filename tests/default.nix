{ makeTest ? import <nixpkgs/nixos/tests/make-test-python.nix>
, eval-config ? import <nixpkgs/nixos/lib/eval-config.nix>
, pkgs ? (import <nixpkgs> { })
}:
let
  lib = pkgs.lib;
  diskoLib = import ../lib { inherit lib makeTest eval-config; };
  makeDiskoTest = diskoLib.testLib.makeDiskoTest;

  allTestFilenames =
    builtins.map (lib.removeSuffix ".nix") (
      builtins.filter
        (x: lib.hasSuffix ".nix" x && x != "default.nix")
        (lib.attrNames (builtins.readDir ./.))
    );

  allTests = lib.genAttrs allTestFilenames (test: import (./. + "/${test}.nix") { inherit makeDiskoTest pkgs; }) // {
    standalone = (pkgs.nixos [ ../example/stand-alone/configuration.nix ]).config.system.build.toplevel;
  };
in
allTests
