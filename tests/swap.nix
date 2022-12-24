{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = ../example/swap.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("swapon --show >&2");
    machine.succeed("""
      lsblk --json |
        jq -e '.blockdevices[] |
          select(.name == "vda") |
          .children[] |
          select(.name == "vda3") |
          .children[0].mountpoints[0] == "[SWAP]"
        '
    """);
  '';
  extraConfig = {
    environment.systemPackages = [ pkgs.jq ];
  };
}
