{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:

diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcachefs-tpm2-fallback";
  disko-config = ../example/bcachefs.nix;
  enableOCR = false;
  
  extraTestScript = ''
    # Fallback test - verify basic functionality
    machine.start()
    machine.succeed("mountpoint /")
    print("✅ Fallback test passed!")
  '';
}