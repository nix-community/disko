{ pkgs ? import <nixpkgs> {}
, mode ? "mount"
, diskoFile
, ... }@args:
let
  disko = import ./. { inherit (pkgs) lib; };
  diskFormat = import diskoFile;
  diskoEval = if (mode == "create") then
    disko.createScript diskFormat pkgs
  else if (mode == "mount") then
    disko.mountScript diskFormat pkgs
  else
    builtins.abort "invalid mode"
  ;
in diskoEval
