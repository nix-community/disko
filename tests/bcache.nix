{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
let
  lib = pkgs.lib;
  generator = pkgs.callPackage ../. { checked = true; };
  wrongBackingConfig = {
    disko.devices = {
      disk = {
        cache-disk = {
          type = "disk";
          device = "/dev/my-cache-disk";
          content = {
            type = "gpt";
            partitions = {
              boot = {
                size = "1M";
                type = "EF02";
              };
              boot-fs = {
                size = "500M";
                content = {
                  type = "bcache_backing";
                  set = "wrong";
                };
              };
              cache = {
                size = "100%";
                content = {
                  type = "bcache_cache";
                  set = "wrong";
                };
              };
            };
          };
        };
      };
      bcache.wrong = {
        type = "bcache";
        device = "/dev/bcache0";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/wrong";
        };
      };
    };
  };
  wrongBackingMount = generator._cliMount (diskoLib.testLib.prepareDiskoConfig wrongBackingConfig (lib.tail diskoLib.testLib.devices)) pkgs;
in
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcache";
  disko-config = ../example/bcache.nix;
  extraInstallerConfig = {
    boot.kernelModules = [ "bcache" ];
  };
  # The harness assigns VM disks in attribute-name order and boots the first
  # one, so the example keeps its boot disk (cache-disk) sorted before storage.
  # Runs after the harness's unmount -> mount cycle.
  postMount = ''
    # Regression: unmount must not detach the cache from the backing device.
    machine.succeed("test -e /sys/block/bcache0/bcache/cache")
    machine.succeed("grep -qE 'clean|dirty' /sys/block/bcache0/bcache/state")
    machine.succeed("grep -qF '[writeback]' /sys/block/bcache0/bcache/cache_mode")

    # An unrelated bcache set on loop devices must survive every disko
    # operation below (unmount, mount, destroy, fresh format).
    machine.succeed("truncate -s 256M /tmp/foreign-cache.img /tmp/foreign-backing.img")
    foreign_cache = machine.succeed("losetup -f --show /tmp/foreign-cache.img").strip()
    foreign_backing = machine.succeed("losetup -f --show /tmp/foreign-backing.img").strip()
    machine.succeed(f"${pkgs.bcache-tools}/bin/make-bcache --bucket 64k -C {foreign_cache} -B {foreign_backing} --force")
    for member in (foreign_cache, foreign_backing):
        name = member.removeprefix("/dev/")
        machine.succeed(f"udevadm settle; test -e /sys/class/block/{name}/bcache || echo {member} > /sys/fs/bcache/register")
    foreign_backing_name = foreign_backing.removeprefix("/dev/")
    machine.wait_until_succeeds(f"test -e /sys/class/block/{foreign_backing_name}/bcache/dev/bcache/cache")
    foreign_dev = machine.succeed(f"basename $(readlink -f /sys/class/block/{foreign_backing_name}/bcache/dev)").strip()
    assert foreign_dev != "bcache0", foreign_dev

    def assert_foreign_alive():
        machine.succeed(f"test -b /dev/{foreign_dev}")
        machine.succeed(f"test -e /sys/block/{foreign_dev}/bcache/cache")
  '';
  postDisko = ''
    assert_foreign_alive()

    # Verify make-bcache wrote metadata to both member devices.
    machine.succeed("bcache-super-show /dev/disk/by-partlabel/disk-cache-disk-cache >&2")
    machine.succeed("bcache-super-show /dev/disk/by-partlabel/disk-storage-backing >&2")

    machine.succeed("mountpoint /mnt")
    machine.succeed("findmnt -n -o FSTYPE /mnt | grep -q ext4")
    machine.succeed("grep -qF '[writeback]' /sys/block/bcache0/bcache/cache_mode")
    machine.succeed("echo 'bcache test data' > /mnt/testfile")
    machine.succeed("grep -q 'bcache test data' /mnt/testfile")

    # Cold-style mount-only reassembly: unmount must stop the set and release
    # our cache set, and the mount script must bring /dev/bcache0 back.
    cache_name = machine.succeed("basename $(readlink -f /dev/disk/by-partlabel/disk-cache-disk-cache)").strip()
    expected_backing = machine.succeed("basename $(readlink -f /dev/disk/by-partlabel/disk-storage-backing)").strip()
    machine.succeed("umount /mnt/boot")
    machine.succeed(disko_unmount)
    machine.succeed("test ! -b /dev/bcache0")
    machine.succeed(f"test ! -e /sys/class/block/{cache_name}/bcache")
    assert_foreign_alive()
    machine.succeed(disko_mount)
    machine.succeed(f'test "$(cat /sys/block/bcache0/bcache/backing_dev_name)" = "{expected_backing}"')
    machine.succeed("test -e /sys/block/bcache0/bcache/cache")
    machine.succeed("grep -q 'bcache test data' /mnt/testfile")

    # Regression: a stale filesystem signature on the backing partition must
    # not surface through /dev/bcache0 and trick content `_create` into
    # skipping format. Creation must remove the raw signature before
    # make-bcache, which rejects non-bcache superblocks even with --force.
    machine.succeed("umount /mnt/boot")
    machine.succeed(disko_unmount)
    machine.succeed("wipefs --all --force /dev/disk/by-partlabel/disk-storage-backing")
    machine.succeed("wipefs --all --force /dev/disk/by-partlabel/disk-cache-disk-cache")
    machine.succeed("mkfs.btrfs -f /dev/disk/by-partlabel/disk-storage-backing")
    machine.succeed("blkid -o export /dev/disk/by-partlabel/disk-storage-backing | grep -q '^TYPE=btrfs$'")
    machine.succeed(disko_format)
    machine.succeed(disko_mount)
    machine.succeed("blkid -o export /dev/bcache0 | grep -q '^TYPE=ext4$'")
    machine.succeed("findmnt -n -o FSTYPE /mnt | grep -q ext4")
    assert_foreign_alive()

    # A mount-only config expecting a different backing device must not reuse an
    # unrelated active /dev/bcache0.
    machine.succeed("umount /mnt/boot")
    machine.succeed("wipefs -a /dev/disk/by-partlabel/disk-cache-disk-boot-fs")
    machine.succeed("${pkgs.bcache-tools}/bin/make-bcache -B /dev/disk/by-partlabel/disk-cache-disk-boot-fs --force")
    machine.succeed(
        "set +e; "
        "${lib.getExe wrongBackingMount} >/tmp/wrong-bcache-mount.log 2>&1; "
        "status=$?; "
        "test $status -ne 0; "
        "grep -q 'is attached to backing' /tmp/wrong-bcache-mount.log"
    )

    # Destroy releases the stray backing set on the wiped disk but leaves the
    # foreign set alone; recreate a clean target for the boot test.
    machine.succeed(f"{disko_destroy_format_mount} --yes-wipe-all-disks")
    assert_foreign_alive()
    machine.succeed("mountpoint /mnt/boot")
  '';
  extraTestScript = ''
    machine.succeed("findmnt -n -o SOURCE / | grep -q bcache0")
    machine.succeed("test -e /sys/block/bcache0/bcache/cache")
    machine.succeed("grep -qF '[writeback]' /sys/block/bcache0/bcache/cache_mode")
  '';
  efi = false;
}
