{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
let
  name = "btrfs-mountoptions-consistency-guardrail";
  disko = pkgs.callPackage ../. {
    checked = true;
    inherit diskoLib;
  };
  disko-config = pkgs.lib.recursiveUpdate (import ../example/btrfs-subvolumes.nix) {
    # Intentionally conflicting filesystem-wide mount options across mounted subvolumes.
    disko.devices.disk.main.content.partitions.root.content.subvolumes = {
      "/rootfs".mountOptions = [ "compress=zstd" ];
      "/home".mountOptions = [ "compress=no" ];
    };
  };

  # The guardrail throws during evaluation; this test validates that behavior directly.
  evalResult = builtins.tryEval (builtins.deepSeq (disko._cliMount disko-config pkgs) true);
in
assert (!evalResult.success);
pkgs.writeText name "ok\n"
