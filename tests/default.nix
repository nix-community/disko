{ makeTest ? import <nixpkgs/nixos/tests/make-test-python.nix>
, eval-config ? import <nixpkgs/nixos/lib/eval-config.nix>
, pkgs ? (import <nixpkgs> { })
}@args:
let
  inherit (pkgs) lib;
  inherit ((pkgs.callPackage ./lib.nix { inherit makeTest eval-config; })) makeDiskoTest;

  evalTest = name: configFile: let
    disko-config = import configFile;
  in {
    "${name}-tsp-create" = pkgs.writeScript "create" ((pkgs.callPackage ../. { }).create disko-config);
    "${name}-tsp-mount" = pkgs.writeScript "mount" ((pkgs.callPackage ../. { }).mount disko-config);
  };

  allTestFilenames =
    builtins.map (lib.removeSuffix ".nix") (
      builtins.filter
        (x: lib.hasSuffix ".nix" x && x != "default.nix" && x != "lib.nix")
        (lib.attrNames (builtins.readDir ./.))
    );

  allTests = lib.genAttrs allTestFilenames (test: import (./. + "/${test}.nix") { inherit makeDiskoTest pkgs; }) //
             evalTest "lvm-luks-example" ../example/config.nix // {
               standalone = (pkgs.nixos [ ../example/stand-alone/configuration.nix ]).config.system.build.toplevel;
             };
in
allTests
