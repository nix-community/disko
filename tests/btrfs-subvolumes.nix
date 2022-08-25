{ pkgs ? (import <nixpkgs> {})
, makeDiskoTest ? (pkgs.callPackage ./lib.nix {}).makeDiskoTest
}:
makeDiskoTest {
  disko-config = import ../example/btrfs-subvolumes.nix;
  extraTestScript = ''
    machine.succeed("test -e /mnt/test");
    machine.succeed("btrfs subvolume list /mnt | grep -qs 'path test$'");
  '';
}

