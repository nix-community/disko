{
  pkgs ? import <nixpkgs> { },
  ...
}:
(pkgs.nixos [
  ../example/stand-alone/configuration.nix
  { documentation.enable = false; }
]).config.system.build.toplevel
