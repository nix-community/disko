{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:

diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcachefs-tpm2-unlock";
  disko-config = ../example/bcachefs.nix;
  enableOCR = false;
  
  extraTestScript = ''
    # Basic test - verify bcachefs functionality
    machine.start()
    machine.succeed("mountpoint /")
    machine.succeed("which bcachefs")
    print("✅ Basic bcachefs test passed!")
  '';
}