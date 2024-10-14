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

  diskoAttr =
    if noDeps then
      {
        format = "formatScriptNoDeps";
        mount = "mountScriptNoDeps";
        disko = "diskoScriptNoDeps";

        # legacy aliases
        create = "createScriptNoDeps";
        zap_create_mount = "diskoScriptNoDeps";
      }.${mode}
    else
      {
        format = "formatScript";
        mount = "mountScript";
        disko = "diskoScript";

        # legacy aliases
        create = "createScript";
        zap_create_mount = "diskoScript";
      }.${mode};

  hasDiskoConfigFlake =
    diskoFile != null || lib.hasAttrByPath [ "diskoConfigurations" flakeAttr ] (builtins.getFlake flake);

  hasDiskoModuleFlake =
    lib.hasAttrByPath [ "nixosConfigurations" flakeAttr "config" "disko" "devices" ] (builtins.getFlake flake);

  diskFormat =
    let
      diskoConfig =
        if diskoFile != null then
          import diskoFile
        else
          (builtins.getFlake flake).diskoConfigurations.${flakeAttr};
    in
    if builtins.isFunction diskoConfig then
      diskoConfig ({ inherit lib; } // args)
    else
      diskoConfig;

  diskoEval =
    disko.${diskoAttr} diskFormat pkgs;

  diskoScript =
    if hasDiskoConfigFlake then
      diskoEval
    else if (lib.traceValSeq hasDiskoModuleFlake) then
      (builtins.getFlake flake).nixosConfigurations.${flakeAttr}.config.system.build.${diskoAttr}
    else
      (builtins.abort "couldn't find `diskoConfigurations.${flakeAttr}` or `nixosConfigurations.${flakeAttr}.config.disko.devices`");

in
diskoScript
