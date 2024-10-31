{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../src/disko_lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "lvm-thin";
  disko-config = ../../example/lvm-thin.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /home");
  '';
}
