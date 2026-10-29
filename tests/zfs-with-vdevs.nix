{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "zfs-with-vdevs";
  disko-config = ../example/zfs-with-vdevs.nix;
  extraInstallerConfig.networking.hostId = "8425e349";
  extraSystemConfig = {
    networking.hostId = "8425e349";
  };
  extraTestScript = ''
    import json

    def assert_property(ds, property, expected_value):
        out = machine.succeed(f"zfs get -H {property} {ds} -o value").rstrip()
        assert (
            out == expected_value
        ), f"Expected {property}={expected_value} on {ds}, got: {out}"

    def canonical_path(path):
        return machine.succeed(f"readlink -f {shlex.quote(path)}").strip()

    def by_partlabel(label):
        return canonical_path(f"/dev/disk/by-partlabel/{label}")

    # These fields are 0 if l2arc is disabled
    assert (
        machine.succeed(
            "cat /proc/spl/kstat/zfs/arcstats"
            " | grep '^l2_' | tr -s ' '"
            " | cut -s -d ' ' -f3 | uniq"
        ).strip() != "0"
    ), "Excepted cache to be utilized."

    assert_property("zroot", "compression", "zstd")
    assert_property("zroot/zfs_fs", "com.sun:auto-snapshot", "true")
    assert_property("zroot/zfs_fs", "compression", "zstd")
    machine.succeed("mountpoint /zfs_fs");

    # `zpool status -j` groups vdevs by class at the pool level: `vdevs` (normal data, wrapped under
    # the `zroot` root vdev) plus `dedup`, `special`, `logs`, `l2cache`, `spares`. Each entry in a
    # group is either a leaf (just a device path) or a mirror vdev with nested `vdevs`. Bucket each
    # leaf into (class, in_mirror, canonical path) and diff against the expected layout.
    def collect_leaves(class_name, entries):
        out = []
        for name, entry in entries.items():
            if entry.get("vdev_type") == "mirror":
                out.extend((class_name, "mirror", canonical_path(child)) for child in entry["vdevs"])
            else:
                out.append((class_name, "single", canonical_path(name)))
        return out

    data = json.loads(machine.succeed("zpool status -P -L -j zroot"))
    pool = next(iter(data["pools"].values()))
    actual_leaves = sorted(
        collect_leaves("normal",  pool["vdevs"]["zroot"]["vdevs"])
        + collect_leaves("dedup",   pool.get("dedup", {}))
        + collect_leaves("special", pool.get("special", {}))
        + collect_leaves("log",     pool.get("logs", {}))
        + collect_leaves("l2cache", pool.get("l2cache", {}))
        + collect_leaves("spare",   pool.get("spares", {}))
    )
    expected_leaves = sorted([
        ("normal",  "single", by_partlabel("disk-data1-zfs")),
        ("normal",  "mirror", by_partlabel("disk-data2-zfs")),
        ("normal",  "mirror", by_partlabel("disk-data3-zfs")),
        ("dedup",   "single", by_partlabel("disk-dedup3-zfs")),
        ("dedup",   "mirror", by_partlabel("disk-dedup1-zfs")),
        ("dedup",   "mirror", by_partlabel("disk-dedup2-zfs")),
        ("special", "single", by_partlabel("disk-special3-zfs")),
        ("special", "mirror", by_partlabel("disk-special1-zfs")),
        ("special", "mirror", by_partlabel("disk-special2-zfs")),
        ("log",     "single", by_partlabel("disk-log3-zfs")),
        ("log",     "mirror", by_partlabel("disk-log1-zfs")),
        ("log",     "mirror", by_partlabel("disk-log2-zfs")),
        ("l2cache", "single", by_partlabel("disk-cache-zfs")),
        ("spare",   "single", by_partlabel("disk-spare-zfs")),
    ])
    assert actual_leaves == expected_leaves, (
        "Incorrect pool layout."
        f"\nExpected: {json.dumps(expected_leaves, indent=2)}"
        f"\nActual:   {json.dumps(actual_leaves, indent=2)}"
    )
  '';
}
