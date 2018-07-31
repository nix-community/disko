# usage: nix-instantiate --eval --json --strict example | jq -r .

with import ../lib;

{
  config = config "/dev/sda" (import ./config.nix);
  create = create "/dev/sda" (import ./config.nix);
  mount = mount "/dev/sda" (import ./config.nix);
}
