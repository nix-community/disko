{ makeTest ? import <nixpkgs/nixos/tests/make-test-python.nix>
, pkgs ? (import <nixpkgs> { })
}@args:
let
  lib = pkgs.lib;
  makeDiskoTest = (pkgs.callPackage ./lib.nix { inherit makeTest; }).makeDiskoTest;
  allTestFilenames =
    builtins.map (lib.removeSuffix ".nix") (
      builtins.filter
        (x: lib.hasSuffix ".nix" x && x != "default.nix" && x != "lib.nix")
        (lib.attrNames (builtins.readDir ./.))
    );

  allTests = lib.genAttrs (allTestFilenames) (test: import (./. + "/${test}.nix") { inherit pkgs makeDiskoTest; });
in
allTests
