{ pkgs ? import <nixpkgs> {}
, mode ? "mount"
, fromFlake ? null
, diskoFile
, ... }@args:
let
  disko = import ./. { };
  diskFormat =
    if fromFlake != null
    then (builtins.getFlake fromFlake) + "/${diskoFile}"
    else import diskoFile;
  diskoEval = if (mode == "create") then
    disko.createScript diskFormat pkgs
  else if (mode == "mount") then
    disko.mountScript diskFormat pkgs
  else
    builtins.abort "invalid mode"
  ;
in diskoEval
