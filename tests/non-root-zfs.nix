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

    machine.fail("mountpoint /mnt/storage2")
    machine.succeed("mountpoint /mnt/storage2/dataset")

    filesystem = machine.execute("stat --file-system --format=%T /mnt/storage2")[1].rstrip()
    print(f"/mnt/storage2 {filesystem=}")
    assert filesystem != "zfs", "/mnt/storage should not be ZFS"

    filesystem = machine.execute("stat --file-system --format=%T /mnt/storage2/dataset")[1].rstrip()
    print(f"/mnt/storage2/dataset {filesystem=}")
    assert filesystem == "zfs", "/mnt/storage/dataset is not ZFS"
  '';
  extraTestScript = ''
    machine.succeed("mountpoint /storage")
    machine.succeed("mountpoint /storage/dataset")

    filesystem = machine.execute("stat --file-system --format=%T /storage")[1].rstrip()
    print(f"/storage {filesystem=}")
    assert filesystem == "zfs", "/storage is not ZFS"

    machine.fail("mountpoint /storage2")
    machine.succeed("mountpoint /storage2/dataset")

    filesystem = machine.execute("stat --file-system --format=%T /storage2")[1].rstrip()
    print(f"/storage2 {filesystem=}")
    assert filesystem != "zfs", "/storage should not be ZFS"

    filesystem = machine.execute("stat --file-system --format=%T /storage2/dataset")[1].rstrip()
    print(f"/storage2/dataset {filesystem=}")
    assert filesystem == "zfs", "/storage/dataset is not ZFS"
  '';
}
