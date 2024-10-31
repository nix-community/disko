{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../src/disko_lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "with-lib";
  disko-config = ../../example/with-lib.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
  efi = false;
}
