{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest (let
  disko-config = import ../example/swap.nix;
in {
  inherit pkgs;
  name = "swap";
  inherit disko-config;
  inherit (disko-config.disko.tests) extraDiskoConfig;
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
})
