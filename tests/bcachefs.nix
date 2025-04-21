{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcachefs";
  disko-config = ../example/bcachefs.nix;
  enableOCR = true;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    # @todo Verify all devices are part of the filesystem.
    # @todo Check device labels and group assignments.
    # Verify mount options were applied.
    machine.succeed("mount | grep ' / ' | grep -q 'compression=lz4'");
    machine.succeed("mount | grep ' / ' | grep -q 'background_compression=lz4'");
    # @todo Verify mountpoint dependency order was respected.
    # @todo Add tests for subvolumes.
    # Print debug information.
    machine.succeed("lsblk >&2");
    machine.succeed("lsblk -f >&2");
    machine.succeed("mount >&2");
  '';
  # extraSystemConfig = { pkgs, ... }: {
  #   # @todo Do we need to add any attributes here?
  #   boot = {
  #     supportedFilesystems = [ "bcachefs" ];
  #     initrd = {
  #       supportedFilesystems = [ "bcachefs" ];
  #       # systemd.enable = false;
  #     };
  #   };
  #   environment.systemPackages = [
  #     pkgs.bcachefs-tools
  #     pkgs.util-linux
  #   ];
  # };
  # extraInstallerConfig = {
  #   # @todo Do we need to add any attributes here?
  # };
  bootCommands = ''
    machine.wait_for_text("enter passphrase for");
    machine.send_chars("secretsecret\n");
  '';
}
