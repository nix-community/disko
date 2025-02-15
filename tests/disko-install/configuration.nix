{
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/testing/test-instrumentation.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/profiles/minimal.nix")
  ];

  networking.hostName = "disko-machine";

  # do not try to fetch stuff from the internet
  nix.settings = {
    substituters = lib.mkForce [ ];
    hashed-mirrors = null;
    connect-timeout = 3;
    flake-registry = pkgs.writeText "flake-registry" ''{"flakes":[],"version":2}'';
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
  services.openssh.enable = true;
  boot.kernelParams =
    [ "console=tty0" ]
    ++ (lib.optional (pkgs.stdenv.hostPlatform.isAarch) "ttyAMA0,115200")
    ++ (lib.optional (pkgs.stdenv.hostPlatform.isRiscV64) "ttySIF0,115200")
    ++ [ "console=ttyS0,115200" ];

  # reduce closure size
  nixpkgs.flake.setFlakeRegistry = false;
  nixpkgs.flake.setNixPath = false;
  nix.registry.nixpkgs.to = { };
  documentation.doc.enable = false;
  documentation.man.enable = false;
}
