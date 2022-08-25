{ pkgs ? (import <nixpkgs> {})
, makeTest ? import <nixpkgs/nixos/tests/make-test-python.nix>
, ...
}:
{
  makeDiskoTest = {
    disko-config,
    extraTestScript,
    extraConfig ? {}
  }:
  let
    lib = pkgs.lib;
    makeTest' = args:
      makeTest args {
        inherit pkgs;
        inherit (pkgs) system;
      };
    tsp-create = pkgs.writeScript "create" ((pkgs.callPackage ../. {}).create disko-config);
    tsp-mount = pkgs.writeScript "mount" ((pkgs.callPackage ../. {}).mount disko-config);
    num-disks = builtins.length (builtins.filter (x: builtins.match "vd." x == []) (lib.attrNames disko-config.content));
  in makeTest' {
    name = "disko";

    nodes.machine =
      { config, pkgs, modulesPath, ... }:

      {
        imports = [
          (modulesPath + "/profiles/installation-device.nix")
          (modulesPath + "/profiles/base.nix")
        ];

        # speed-up eval
        documentation.enable = false;

        virtualisation.emptyDiskImages = builtins.genList (_: 512) num-disks;
      } // extraConfig;

    testScript = ''
      machine.succeed("echo 'secret' > /tmp/secret.key");
      machine.succeed("${tsp-create}");
      machine.succeed("${tsp-mount}");
      machine.succeed("${tsp-mount}"); # verify that the command is idempotent
      ${extraTestScript}
    '';
  };
}
