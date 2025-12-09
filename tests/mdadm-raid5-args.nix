{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "mdadm-raid5-args";
  disko-config = ../example/mdadm-raid5-args.nix;
  extraTestScript = ''
    machine.succeed("test -b /dev/md/raid5");
    machine.succeed("mountpoint /");
  '';
  efi = false;
}
