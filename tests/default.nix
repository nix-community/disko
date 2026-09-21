# Main test runner for bcachefs TPM2 unlocking
{
  pkgs,
  makeTest,
  eval-config,
  qemu-common,
}:

{
  # TPM2 tests temporarily disabled - need to be restructured to use disko-config format
  # See bcachefs.nix for the proper test structure with separate disko-config file

  # bcachefs-tpm2-unit-tests = import ./bcachefs-tpm2-unit-tests.nix { inherit pkgs makeTest; };
  # bcachefs-tpm2-unlock = import ./bcachefs-tpm2-unlock.nix { inherit pkgs makeTest; };
  # bcachefs-tpm2-fallback = import ./bcachefs-tpm2-fallback.nix { inherit pkgs makeTest; };
  # bcachefs-tpm2-performance = import ./bcachefs-tpm2-performance.nix { inherit pkgs makeTest; };
  # bcachefs-tpm2-edge-cases = import ./bcachefs-tpm2-edge-cases.nix { inherit pkgs makeTest; };
  # bcachefs-tpm2-vm-test = import ./bcachefs-tpm2-vm-test.nix { inherit pkgs makeTest; };
}
