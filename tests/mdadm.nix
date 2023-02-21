{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  name = "mdadm";
  disko-config = ../example/mdadm.nix;
  extraTestScript = ''
    machine.succeed("test -b /dev/md/raid1");
    machine.succeed("mountpoint /");
  '';
  efi = false;
  grub-devices = [ "/dev/vdb" "/dev/vdc" ];
}
