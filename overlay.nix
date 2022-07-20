final: prev: rec {
  disko.env = import ./diskoEnv.nix {pkgs = final;};
  disko.lib = import ./lib {diskoEnv = disko.env; lib = final.lib;};
}