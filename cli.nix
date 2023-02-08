{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
, mode ? "mount"
, flake ? null
, flakeAttr ? null
, diskoFile ? null
, rootMountPoint ? "/mnt"
, noDeps ? false
, ...
}@args:
let
  disko = import ./. {
    inherit rootMountPoint;
    inherit lib;
  };

  diskFormat =
    if flake != null then
      (pkgs.lib.attrByPath [ "diskoConfigurations" flakeAttr ] (builtins.abort "${flakeAttr} does not exist") (builtins.getFlake flake)) args
    else
      import diskoFile ({ inherit lib; } // args);

  diskoEval =
    if noDeps then
      if (mode == "create") then
        disko.createScriptNoDeps diskFormat pkgs
      else if (mode == "mount") then
        disko.mountScriptNoDeps diskFormat pkgs
      else if (mode == "zap_create_mount") then
        disko.zapCreateMountScriptNoDeps diskFormat pkgs
      else
        builtins.abort "invalid mode"
    else
      if (mode == "create") then
        disko.createScript diskFormat pkgs
      else if (mode == "mount") then
        disko.mountScript diskFormat pkgs
      else if (mode == "zap_create_mount") then
        disko.zapCreateMountScript diskFormat pkgs
      else
        builtins.abort "invalid mode"
  ;
in
diskoEval
