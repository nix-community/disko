{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "swap";
  disko-config = ../example/swap.nix;
  extraTestScript = ''
    import json
    machine.succeed("mountpoint /");
    machine.succeed("swapon --show >&2");
    out = json.loads(machine.succeed("lsblk --json /dev/vda"))
    mnt_point = out["blockdevices"][0]["children"][1]["children"][0]["mountpoints"][0]
    assert mnt_point == "[SWAP]"
  '';
  extraSystemConfig = {
    environment.systemPackages = [ pkgs.jq ];
  };
}
