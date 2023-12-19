{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "non-root-zfs";
  disko-config = ../example/non-root-zfs.nix;
  extraInstallerConfig.networking.hostId = "8425e349";
  extraSystemConfig.networking.hostId = "8425e349";
  postDisko = ''
    machine.succeed("mountpoint /mnt/storage")
    machine.succeed("mountpoint /mnt/storage/dataset")

    filesystem = machine.execute("stat --file-system --format=%T /mnt/storage")[1].rstrip()
    print(f"/mnt/storage {filesystem=}")
    assert filesystem == "zfs", "/mnt/storage is not ZFS"
  '';
  extraTestScript = ''
    machine.succeed("mountpoint /storage")
    machine.succeed("mountpoint /storage/dataset")

    filesystem = machine.execute("stat --file-system --format=%T /storage")[1].rstrip()
    print(f"/mnt/storage {filesystem=}")
    assert filesystem == "zfs", "/storage is not ZFS"
  '';
}
