# usage: nix-instantiate --eval --json --strict example | jq -r .

let
  # TODO: get rid of NIX_PATH dependency here
  pkgs = import <nixpkgs> {};
in
with import ../lib { inherit (pkgs) lib;};

{
  config = config (import ./config.nix);
  create = create (import ./config.nix);
  mount = mount (import ./config.nix);
}
