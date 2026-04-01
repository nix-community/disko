{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
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
  extraTestScript = ''
    # Verify bcache device exists and is a block device
    machine.succeed("test -b /dev/bcache0")

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
  '';
  efi = false;
}
