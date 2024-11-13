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

  hasDiskoFile = diskoFile != null;

  diskoAttr =
    (if noDeps then
      (if hasDiskoFile then
        {
          destroy = "_cliDestroyNoDeps";
          format = "_cliFormatNoDeps";
          mount = "_cliMountNoDeps";

          "format,mount" = "_cliFormatMountNoDeps";
          "destroy,format,mount" = "_cliDestroyFormatMountNoDeps";
        }
      else
        {
          destroy = "destroyNoDeps";
          format = "formatNoDeps";
          mount = "mountNoDeps";

          "format,mount" = "formatMountNoDeps";
          "destroy,format,mount" = "destroyFormatMountNoDeps";
        }) // {
        # legacy aliases
        disko = "diskoScriptNoDeps";
        create = "createScriptNoDeps";
        zap_create_mount = "diskoScriptNoDeps";
      }
    else
      (if hasDiskoFile then
        {
          destroy = "_cliDestroy";
          format = "_cliFormat";
          mount = "_cliMount";

          "format,mount" = "_cliFormatMount";
          "destroy,format,mount" = "_cliDestroyFormatMount";
        }
      else
        {
          destroy = "destroy";
          format = "format";
          mount = "munt";

          "format,mount" = "formatMount";
          "destroy,format,mount" = "destroyFormatMount";
        }) // {
        # legacy aliases
        disko = "diskoScript";
        create = "createScript";
        zap_create_mount = "diskoScript";
      }
    ).${mode};

  hasDiskoConfigFlake =
    hasDiskoFile || lib.hasAttrByPath [ "diskoConfigurations" flakeAttr ] (builtins.getFlake flake);

  hasDiskoModuleFlake =
    lib.hasAttrByPath [ "nixosConfigurations" flakeAttr "config" "disko" "devices" ] (builtins.getFlake flake);


  diskFormat =
    let
      diskoConfig =
        if hasDiskoFile then
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
      (builtins.getFlake flake).nixosConfigurations.${flakeAttr}.config.system.build.${diskoAttr} or (
        pkgs.writeShellScriptBin "disko-compat-error" ''
          echo 'Error: Attribute `nixosConfigurations.${flakeAttr}.config.system.build.${diskoAttr}` >&2
          echo '       not found in flake `${flake}`!' >&2
          echo '       This is probably caused by the locked version of disko in the flake' >&2
          echo '       being different from the version of disko you executed.' >&2
          echo 'EITHER set the `disko` input of your flake to `github:nix-community/disko/latest`,' >&2
          echo '       run `nix flake update disko` in the flake directory and then try again,' >&2
          echo 'OR run `nix run github:nix-community/disko/v1.9.0 -- --help` and use one of its modes.' >&2
          exit 1;''
      )
    else
      (builtins.abort "couldn't find `diskoConfigurations.${flakeAttr}` or `nixosConfigurations.${flakeAttr}.config.disko.devices`");

in
diskoScript
