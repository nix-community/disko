# usage: nix-instantiate --eval --json --strict example | jq -r .

let
  cfg = import ./config.nix;
  #cfg = import ./config-gpt-bios.nix;
in
# TODO: get rid of NIX_PATH dependency here
with import ../. {};

{
  config = config cfg;
  create = create cfg;
  mount = mount cfg;
}
