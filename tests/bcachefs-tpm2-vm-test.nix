{ pkgs, makeTest, ... }:

let
  diskoLib = pkgs.callPackage ../lib { };
in
diskoLib.testLib.makeDiskoTest {
  name = "bcachefs-tpm2-vm-test";

  nodes.machine =
    { pkgs, ... }:
    {
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
