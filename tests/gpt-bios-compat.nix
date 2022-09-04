{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = import ../example/gpt-bios-compat.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /mnt");
    machine.succeed("grub-install --target=i386-pc /dev/vdb");
  '';
}
