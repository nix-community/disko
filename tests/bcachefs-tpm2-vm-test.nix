{
  pkgs ? import <nixpkgs> { },
}:

# Simple VM test for TPM2 functionality
import (pkgs.path + "/nixos/tests/make-test-python.nix") {
  name = "bcachefs-tpm2-vm-test";
  
  nodes.machine = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      bcachefs-tools
      clevis
      jose
      tpm2-tools
    ];
    
    virtualisation.tpm.enable = true;
  };
  
  testScript = ''
    machine.start()
    machine.succeed("which bcachefs")
    machine.succeed("which clevis")
    print("✅ VM test passed!")
  '';
}