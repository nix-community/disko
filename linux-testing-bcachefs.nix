# nixpkgs's variant is broken because they have non-applying patches on top of the latest kernel,
# instead of using kernel.

{ buildLinux
, fetchFromGitHub
, ...
} @ args:
buildLinux (args // {
  # NOTE: bcachefs-tools should be updated simultaneously to preserve compatibility
  version = "6.3.0-2023-05-21";

  modDirVersion = "6.3.0";

  src = fetchFromGitHub {
    owner = "koverstreet";
    repo = "bcachefs";
    rev = "baaa442cb4abfea84549a3cee863829ee06fb615";
    sha256 = "sha256-c3WQpUopfqHNkmrDS3WDW4WxXIiKobjbNLjwCQSh0zA=";
  };

  kernelPatches = (args.kernelPatches or [ ]) ++ [{
    name = "bcachefs-config";
    patch = null;
    extraConfig = ''
      BCACHEFS_FS m
    '';
  }];
} // (args.argsOverride or { }))
