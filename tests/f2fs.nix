{
  imports = [ ../example/f2fs.nix ];
  disko.test = {
    name = "f2fs";
    extraChecks = ''
      machine.succeed("mountpoint /");
      machine.succeed("lsblk --fs >&2");
    '';
    # so that the installer boots with a f2fs enabled kernel
    nodes.formatter.boot.supportedFilesystems = [ "f2fs" ];
  };
}
