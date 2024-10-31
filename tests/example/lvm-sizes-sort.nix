{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../src/disko_lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "lvm-sizes-sort";
  disko-config = ../../example/lvm-sizes-sort.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /home");
  '';
}
