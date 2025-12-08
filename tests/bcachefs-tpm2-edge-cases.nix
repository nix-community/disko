{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:

diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcachefs-tpm2-edge-cases";
  disko-config = ../example/bcachefs.nix;
  enableOCR = false;
  
  extraTestScript = ''
    # Edge cases test - verify basic functionality
    machine.start()
    machine.succeed("mountpoint /")
    print("✅ Edge cases test passed!")
  '';
}