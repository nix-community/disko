{ pkgs, lib, ... }:
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/vdb";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "500M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                settings.allowDiscards = true;
                passwordFile = "/tmp/secret.key";
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
            };
          };
        };
      };
    };
  };

  disko.test = {
    name = "luks-interactive-login";
    enableOCR = true;
    bootCommands = ''
      machine.wait_for_text("[Pp]assphrase for")
      machine.send_chars("custompassword\n")
    '';
    extraChecks = ''
      machine.succeed("cryptsetup isLuks /dev/vda2");
      machine.succeed("mountpoint /")
    '';

    # FIXME: this override currently does NOT propagate to the install-test
    # nodes. `install-test.nix` sets `disko.devices = testConfigBooted.disko.devices`
    # on each node as a whole-attrset definition. The user's leaf-level
    # override from `defaults` is buried inside its outer-attrset wrapper
    # and discarded by the priority filter at the `disko.devices` option,
    # regardless of `lib.mkForce` on the leaf.
    #
    # Until `install-test.nix` is refactored to set just per-disk leaf
    # paths (rather than the whole `disko.devices` attrset), this test
    # fails at the boot phase: format encrypts with `/tmp/secret.key`'s
    # contents (the test framework writes `secretsecret` there),
    # `bootCommands` types `custompassword`, and the initrd's LUKS unlock
    # mismatches. That failure mode is exactly the assertion the test is
    # designed to make — `defaults` MUST propagate to both `nodes.formatter`
    # (which runs disko's format) and `nodes.machine` (whose initrd reads
    # passwordFile at the prompt). When the structural fix lands, this
    # test starts passing automatically and the demo becomes load-bearing
    # regression coverage for `defaults` propagation.
    defaults = {
      # Test-only LUKS password: overrides the example's `/tmp/secret.key`
      # default. The override fires only inside `system.build.diskoTest` —
      # a user importing this example into their own NixOS config keeps
      # `passwordFile = "/tmp/secret.key"` as the user-facing default.
      disko.devices.disk.main.content.partitions.luks.content.passwordFile = lib.mkForce (
        toString (pkgs.writeText "luks-test-password" "custompassword")
      );
    };
  };
}
