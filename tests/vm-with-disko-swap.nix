# vmWithDisko must not duplicate swapDevices generated from the disko config.
# Regression test for https://github.com/nix-community/disko/issues/1283
{
  pkgs ? import <nixpkgs> { },
  ...
}:
let
  lib = pkgs.lib;
  system = pkgs.nixos [
    ../module.nix
    ../example/swap.nix
    {
      documentation.enable = false;
      system.stateVersion = "26.11";
    }
  ];
  vmSwap = system.config.virtualisation.vmVariantWithDisko.swapDevices;
  uniqueSwapDevices = lib.unique (map (s: s.device) vmSwap);
in
assert (builtins.length vmSwap == builtins.length uniqueSwapDevices);
pkgs.runCommand "test-vm-with-disko-swap" { } "touch $out"
