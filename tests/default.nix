{
  pkgs ? import <nixpkgs> { },
  ...
}:
let
  inherit (pkgs) lib;

  bespoke = [
    "make-disk-image"
    "make-disk-image-impure"
    "mdadm-btrfs-wipe"
    "standalone"
  ];
  incompatible = lib.optionals pkgs.stdenv.buildPlatform.isRiscV64 [
    "zfs"
    "zfs-over-legacy"
    "cli"
    "module"
    "complex"
  ];

  listNix =
    dir:
    map (lib.removeSuffix ".nix") (
      lib.attrNames (
        lib.filterAttrs (n: _: lib.hasSuffix ".nix" n && n != "default.nix") (builtins.readDir dir)
      )
    );

  evalModule =
    file:
    import (pkgs.path + "/nixos/lib/eval-config.nix") {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../module.nix
        file
      ];
    };

  testsDirModule = lib.genAttrs (lib.subtractLists bespoke (listNix ./.)) (
    name: evalModule (./. + "/${name}.nix")
  );

  moduleTests = lib.mapAttrs (_: eval: eval.config.system.build.diskoTest) (
    lib.removeAttrs testsDirModule incompatible
  );

  bespokeTests = lib.genAttrs bespoke (name: import (./. + "/${name}.nix") { inherit pkgs; });
in
moduleTests // bespokeTests
