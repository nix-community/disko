# nixpkgs's variant is broken because they have non-applying patches on top of the latest kernel,
# instead of using kernel.

{ buildLinux
, fetchFromGitHub
, ...
} @ args:
buildLinux (args // {
  # NOTE: bcachefs-tools should be updated simultaneously to preserve compatibility
  version = "6.3.0-2023-05-02";

  modDirVersion = "6.3.0";

  src = fetchFromGitHub {
    owner = "koverstreet";
    repo = "bcachefs";
    rev = "ccc8737427a33228cd43d79dd0c7ed6903dedff0";
    sha256 = "sha256-jqTFE9OZg1GU/W7GnHjtLRfu/l0LYMa3ynHtruY62Og=";
  };

  kernelPatches = (args.kernelPatches or [ ]) ++ [{
    name = "bcachefs-config";
    patch = null;
    extraConfig = ''
      BCACHEFS_FS m
    '';
  }];
} // (args.argsOverride or { }))
