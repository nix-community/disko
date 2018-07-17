# usage: nix-instantiate --eval --json --strict example | jq -r .

with import ../lib;

  disko "/dev/sda" (import ./config.nix)
