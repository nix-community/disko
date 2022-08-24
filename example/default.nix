# usage: nix-instantiate --eval --json --strict example | jq -r .

let
  # TODO: get rid of NIX_PATH dependency here
  pkgs = import <nixpkgs> {};
  cfg = import ./config.nix;
  #cfg = import ./config-gpt-bios.nix;
in
with import ../. { inherit (pkgs) lib;};

{
  config = config cfg;
  create = create cfg;
  mount = mount cfg;
}
