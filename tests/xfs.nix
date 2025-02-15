{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "xfs";
  disko-config = ../example/xfs-with-quota.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");

    machine.succeed("xfs_quota -c 'print' / | grep -q '(pquota)'")
  '';
}
