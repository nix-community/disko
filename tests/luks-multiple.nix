{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "luks-multiple";
  disko-config = ../example/luks-multiple.nix;
  testBoot = false;
  postUnmountPreMount = ''
    machine.fail("mountpoint /mnt/");
    machine.fail("mountpoint /mnt/home");
    machine.fail("${pkgs.cryptsetup}/bin/cryptsetup status root")
    machine.fail("${pkgs.cryptsetup}/bin/cryptsetup status home")
  '';
  postMount = ''
    machine.succeed("mountpoint /mnt/");
    machine.succeed("mountpoint /mnt/home");
    machine.succeed("${pkgs.cryptsetup}/bin/cryptsetup status root")
    machine.succeed("${pkgs.cryptsetup}/bin/cryptsetup status home")
  '';
}
