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
  extraSystemConfig = {
    boot.bcache.enable = true;
  };
  # bcache root requires initrd support that NixOS doesn't fully provide yet;
  # test format/mount/destroy/idempotency only
  testBoot = false;
  testMode = "direct";
  extraTestScript = ''
    # Verify bcache device exists and is a block device
    machine.succeed("test -b /dev/bcache0")

    # Verify make-bcache wrote metadata to both member devices.
    machine.succeed("bcache-super-show /dev/disk/by-partlabel/disk-cache-disk-cache >&2")
    machine.succeed("bcache-super-show /dev/disk/by-partlabel/disk-backing-disk-backing >&2")

    # Verify root is mounted on bcache
    machine.succeed("mountpoint /mnt")

    # Verify cache mode is writeback
    machine.succeed("cat /sys/block/bcache0/bcache/cache_mode | grep -q writeback")

    # Verify the cache is attached (state should be "clean" or "dirty", not "no cache")
    machine.succeed("cat /sys/block/bcache0/bcache/state | grep -qE 'clean|dirty'")

    # Verify a backing device is attached (non-empty name)
    machine.succeed("test -n \"$(cat /sys/block/bcache0/bcache/backing_dev_name)\"")

    # Verify data read/write through bcache works
    machine.succeed("echo 'bcache test data' > /mnt/testfile")
    machine.succeed("grep -q 'bcache test data' /mnt/testfile")

    # Verify the filesystem on bcache is ext4
    machine.succeed("findmnt -n -o FSTYPE /mnt | grep -q ext4")

    # Cold-style mount-only reassembly: stop the active set, unregister cache
    # sets, and ensure the generated mount script brings /dev/bcache0 back.
    expected_backing = machine.succeed("basename $(readlink -f /dev/disk/by-partlabel/disk-backing-disk-backing)").strip()
    machine.succeed(disko_unmount)
    machine.succeed("test ! -b /dev/bcache0")
    machine.succeed("find /sys/fs/bcache -maxdepth 1 -mindepth 1 -type d -exec sh -c 'for cset; do [ ! -e \"$cset/unregister\" ] || echo 1 > \"$cset/unregister\"; done' _ {} + 2>/dev/null || true")
    machine.succeed("udevadm settle --timeout=10 || true")
    machine.succeed(disko_mount)
    machine.succeed("test -b /dev/bcache0")
    machine.succeed(f'test "$(cat /sys/block/bcache0/bcache/backing_dev_name)" = "{expected_backing}"')
    machine.succeed("mountpoint /mnt")

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
  '';
  efi = false;
}
