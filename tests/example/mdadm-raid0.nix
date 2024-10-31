{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../src/disko_lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "mdadm-raid0";
  disko-config = ../../example/mdadm-raid0.nix;
  extraTestScript = ''
    machine.succeed("test -b /dev/md/raid0");
    machine.succeed("mountpoint /");
  '';
  efi = false;
}
