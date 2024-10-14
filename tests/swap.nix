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
    machine.succeed("lsblk -o +PARTTYPENAME --json /dev/vda >&2");
    out = json.loads(machine.succeed("lsblk -o +PARTTYPENAME --json /dev/vda"))

    encrypted_swap_crypt = out["blockdevices"][0]["children"][1]
    mnt_point = encrypted_swap_crypt["children"][0]["mountpoints"][0]
    assert mnt_point == "[SWAP]", f"Expected encrypted swap partition to be mounted as [SWAP], got {mnt_point}"
    part_type = encrypted_swap_crypt["parttypename"]
    # The dm-crypt partition should be labelled as swap, not dm-crypt, see https://github.com/util-linux/util-linux/issues/3238
    assert part_type == "Linux swap", f"Expected encrypted swap container to be of type Linux swap, got {part_type}"

    plain_swap_part = out["blockdevices"][0]["children"][3]
    mnt_point = plain_swap_part["mountpoints"][0]
    assert mnt_point == "[SWAP]", f"Expected swap partition to be mounted as [SWAP], got {mnt_point}"
    part_type = plain_swap_part["parttypename"]
    assert part_type == "Linux swap", f"Expected plain swap partition to be of type Linux swap, got {part_type}"
  '';
  extraSystemConfig = {
    environment.systemPackages = [ pkgs.jq ];
  };
}
