{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "zfs-multi-raidz3";
  disko-config = ../example/zfs-multi-raidz3.nix;
  extraInstallerConfig.networking.hostId = "8425e349";
  extraSystemConfig = {
    networking.hostId = "8425e349";
    # It looks like the 60s of NixOS is sometimes not enough for our virtio-based zpool.
    # This fixes the flakeiness of the test.
    boot.initrd.postResumeCommands = ''
      for i in $(seq 1 120); do
        if zpool list | grep -q zroot || zpool import -N zroot; then
          break
        fi
      done
    '';
  };
  extraTestScript = ''
    def assert_property(ds, property, expected_value):
        out = machine.succeed(f"zfs get -H {property} {ds} -o value").rstrip()
        assert (
            out == expected_value
        ), f"Expected {property}={expected_value} on {ds}, got: {out}"

    assert_property("zroot", "compression", "zstd")
    assert_property("zroot/zfs_fs", "com.sun:auto-snapshot", "true")
    assert_property("zroot/zfs_fs", "compression", "zstd")
    machine.succeed("mountpoint /zfs_fs");

    # Verify the pool has 36 devices total (33 in raidz3 vdevs + 3 spares)
    status_output = machine.succeed("zpool status -P zroot")

    # Count the number of disk devices in the pool
    device_count = 0
    for line in status_output.split("\n"):
        if "/dev/disk/by-partlabel/disk-" in line:
            device_count += 1

    assert device_count == 36, f"Expected 36 devices in pool, found {device_count}"

    # Verify we have 3 raidz3 vdevs
    raidz3_count = status_output.count("raidz3")
    assert raidz3_count == 3, f"Expected 3 raidz3 vdevs, found {raidz3_count}"

    # Verify we have 3 spares
    spares_count = 0
    in_spares_section = False
    for line in status_output.split("\n"):
        if line.strip().startswith("spares"):
            in_spares_section = True
        elif in_spares_section and "/dev/disk/by-partlabel/disk-" in line:
            spares_count += 1
        elif in_spares_section and line.strip() and not line.startswith("\t"):
            in_spares_section = False

    assert spares_count == 3, f"Expected 3 spare devices, found {spares_count}"

    # Verify pool health
    pool_state = machine.succeed("zpool list -H -o health zroot").strip()
    assert pool_state == "ONLINE", f"Expected pool health ONLINE, got {pool_state}"
  '';
}
