# usage: nix-instantiate --eval --json --strict example | jq -r .

with import ../lib;

{
  format = format "/dev/sda" (import ./config.nix);
  config = config "/dev/sda" (import ./config.nix);
}
