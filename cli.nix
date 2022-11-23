{ pkgs ? import <nixpkgs> {}
, mode ? "mount"
, flake ? null
, flakeAttr ? null
, diskoFile ? null
, ... }@args:
let
  disko = import ./. { };

  diskFormat = if flake != null then
    (pkgs.lib.attrByPath [ "diskoConfigurations" flakeAttr ] (builtins.abort "${flakeAttr} does not exist") (builtins.getFlake flake)) args
  else
    import diskoFile args;

  diskoEval = if (mode == "create") then
    disko.createScript diskFormat pkgs
  else if (mode == "mount") then
    disko.mountScript diskFormat pkgs
  else if (mode = "zap_create_mount") then
    disko.zapCreateMount diskFormat pkgs
  else
    builtins.abort "invalid mode"
  ;
in diskoEval
