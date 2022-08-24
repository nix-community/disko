{ makeTest ? import <nixpkgs/nixos/tests/make-test-python.nix>
, pkgs ? (import <nixpkgs> {})
}:
let
  makeTest' = args:
    makeTest args {
      inherit pkgs;
      inherit (pkgs) system;
    };
  disko-config = import ../example/raid.nix;
  tsp-create = pkgs.writeScript "create" ((pkgs.callPackage ../. {}).create disko-config);
  tsp-mount = pkgs.writeScript "mount" ((pkgs.callPackage ../. {}).mount disko-config);
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

      virtualisation.emptyDiskImages = [ 512 512 ];
    };

  testScript = ''
    machine.succeed("echo 'secret' > /tmp/secret.key");
    machine.succeed("${tsp-create}");
    machine.succeed("${tsp-mount}");
    machine.succeed("${tsp-mount}"); # verify that the command is idempotent
    machine.succeed("test -b /dev/md/raid1");
  '';
}
