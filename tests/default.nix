{ makeTest ? import <nixpkgs/nixos/tests/make-test-python.nix>
, eval-config ? import <nixpkgs/nixos/lib/eval-config.nix>
, pkgs ? (import <nixpkgs> { })
}@args:
let
  lib = pkgs.lib;
  makeDiskoTest = (pkgs.callPackage ./lib.nix { inherit makeTest eval-config; }).makeDiskoTest;

  evalTest = name: configFile:
    let
      disko-config = import configFile;
    in
    {
      "${name}-tsp-create" = (pkgs.callPackage ../. { checked = true; }).createScript disko-config pkgs;
      "${name}-tsp-mount" = (pkgs.callPackage ../. { checked = true; }).mountScript disko-config pkgs;
    };

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
