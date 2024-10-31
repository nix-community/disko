{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../src/disko_lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "long-device-name";
  disko-config = ../../example/long-device-name.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
  '';
}
