{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "hybrid-tmpfs-on-root";
  disko-config = ../example/hybrid-tmpfs-on-root.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("findmnt / --types tmpfs");
  '';
}
