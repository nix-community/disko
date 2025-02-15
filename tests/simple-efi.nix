{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "simple-efi";
  disko-config = ../example/simple-efi.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
}
