{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
, flake ? null
, flakeAttr ? null
, diskoFile ? null
, configJsonStr ? null
, rootMountPoint ? "/mnt"
, ...
}@args:
let
  disko = import ./. {
    inherit rootMountPoint;
    inherit lib;
  };

  flake' = (builtins.getFlake flake);

  hasDiskoFile = diskoFile != null;

  hasFlakeDiskoConfig = lib.hasAttrByPath [ "diskoConfigurations" flakeAttr ] flake';

  hasConfigStr = configJsonStr != null;

  hasFlakeDiskoModule =
    lib.hasAttrByPath [ "nixosConfigurations" flakeAttr "config" "disko" "devices" ] flake';

  diskFormat =
    let
      diskoConfig =
        if hasDiskoFile then
          import diskoFile
        else if hasConfigStr then
          (builtins.fromJSON configJsonStr)
        else
          flake'.diskoConfigurations.${flakeAttr};
    in
    if builtins.isFunction diskoConfig then
      diskoConfig ({ inherit lib; } // args)
    else
      diskoConfig;

  evaluatedConfig =
    if hasDiskoFile || hasConfigStr || hasFlakeDiskoConfig then
      disko.eval-disko diskFormat
    else if (lib.traceValSeq hasFlakeDiskoModule) then
      flake'.nixosConfigurations.${flakeAttr}
    else
      (builtins.abort "couldn't find `diskoConfigurations.${flakeAttr}` or `nixosConfigurations.${flakeAttr}.config.disko.devices`");

  diskoConfig = evaluatedConfig.config.disko.devices;

  shouldBeEvaluated = name: (!lib.hasPrefix "_" name) || (name == "_index");
  finalConfig = lib.filterAttrsRecursive (name: value: shouldBeEvaluated name) diskoConfig;
in
finalConfig
