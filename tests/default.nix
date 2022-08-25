{ makeTest ? import <nixpkgs/nixos/tests/make-test-python.nix>
, pkgs ? (import <nixpkgs> {})
}@args:
{
  luks-lvm = import ./luks-lvm.nix args;
  mdadm = import ./mdadm.nix args;
  zfs = import ./zfs.nix args;
}
