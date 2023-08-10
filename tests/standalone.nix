{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
(pkgs.nixos [
  ../example/stand-alone/configuration.nix
  { documentation.enable = false; }
]).config.system.build.toplevel
