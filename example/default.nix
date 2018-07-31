# usage: nix-instantiate --eval --json --strict example | jq -r .

with import ../lib;

{
  config = config (import ./config.nix);
  create = create (import ./config.nix);
  mount = mount (import ./config.nix);
}
