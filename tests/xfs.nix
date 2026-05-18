{
  imports = [ ../example/xfs-with-quota.nix ];
  disko.test = {
    name = "xfs";
    extraChecks = ''
      machine.succeed("mountpoint /");

      machine.succeed("xfs_quota -c 'print' / | grep -q '(pquota)'")
    '';
  };
}
