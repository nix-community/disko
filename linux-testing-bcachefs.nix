# nixpkgs's variant is broken because they have non-applying patches on top of the latest kernel,
# instead of using kernel.

{ lib
, buildLinux
, fetchFromGitHub
, ...
} @ args:
buildLinux (args // {
  # NOTE: bcachefs-tools should be updated simultaneously to preserve compatibility
  version = "6.1.0-2023-02-01";
  modDirVersion = "6.1.0";

  src = fetchFromGitHub {
    owner = "koverstreet";
    repo = "bcachefs";
    rev = "52851ef710d4b906d07d9647e50a97a9e9e5a909";
    sha256 = "sha256-n00qPtHHEHt3FSIRMoP9IJFAdQJNNwabg+WAKppSAS8=";
  };

  kernelPatches = (args.kernelPatches or [ ]) ++ [{
    name = "bcachefs-config";
    patch = null;
    extraConfig = ''
      BCACHEFS_FS m
    '';
  }];
} // (args.argsOverride or { }))
