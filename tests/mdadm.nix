{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = import ../example/mdadm.nix;
  extraTestScript = ''
    machine.succeed("test -b /dev/md/raid1");
    machine.succeed("mountpoint /mnt/raid");
  '';
}
