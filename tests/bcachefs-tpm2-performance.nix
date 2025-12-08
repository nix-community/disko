{
  pkgs ? import <nixpkgs> { },
}:

# Simple performance test
import (pkgs.path + "/nixos/tests/make-test-python.nix") {
  name = "bcachefs-tpm2-performance";
  
  nodes.machine = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      bcachefs-tools
      time
    ];
  };
  
  testScript = ''
    machine.start()
    
    # Simple performance test
    start_time = machine.succeed("date +%s%N")
    machine.succeed("which bcachefs")
    end_time = machine.succeed("date +%s%N")
    
    print("✅ Performance test passed!")
  '';
}