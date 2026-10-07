# A password mismatch during interactive LUKS formatting must let the
# user retry, not abort the whole format script. Retries are capped, and
# both the retry and the final failure report a clear message instead of
# failing silently.
{
  pkgs ? import <nixpkgs> { },
  ...
}:
let
  lib = pkgs.lib;
  disko = import ../. {
    inherit lib;
    checked = true;
  };

  mkDiskoConfig = device: {
    disko.devices.disk.main = {
      type = "disk";
      inherit device;
      content = {
        type = "gpt";
        partitions.luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot-${builtins.baseNameOf device}";
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

  formatRetry = disko._cliFormat (mkDiskoConfig "/dev/vdb") pkgs;
  formatGiveUp = disko._cliFormat (mkDiskoConfig "/dev/vdc") pkgs;
in
pkgs.testers.nixosTest {
  name = "luks-password-mismatch";

  nodes.machine = {
    virtualisation.emptyDiskImages = [
      4096
      4096
    ];
    environment.systemPackages = [ pkgs.cryptsetup ];
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # A mismatched password pair must not abort formatting: the retry loop
    # should prompt again, say so, and succeed once a matching pair is
    # entered.
    machine.succeed(
        "printf 'wrong\\nnotwrong\\nsecretsecret\\nsecretsecret\\n'"
        " | ${lib.getExe formatRetry} > /tmp/retry.log 2>&1"
    )
    machine.succeed(
        "grep -qF 'Passwords did not match, please try again.' /tmp/retry.log"
    )
    machine.succeed("cryptsetup isLuks /dev/vdb1")

    # Three mismatched pairs in a row must give up with a clear error
    # instead of prompting forever or failing silently.
    machine.fail(
        "printf 'a\\nb\\nc\\nd\\ne\\nf\\n'"
        " | ${lib.getExe formatGiveUp} > /tmp/giveup.log 2>&1"
    )
    machine.succeed(
        "grep -qF 'Too many mismatched password attempts' /tmp/giveup.log"
    )
    machine.fail("cryptsetup isLuks /dev/vdc1")
  '';
}
