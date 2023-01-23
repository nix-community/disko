# nixpkgs's variant is broken because they have non-applying patches on top of the latest kernel,
# instead of using kernel.

{ lib
, buildLinux
, fetchFromGitHub
, ...
} @ args:
buildLinux (args // {
  # NOTE: bcachefs-tools should be updated simultaneously to preserve compatibility
  version = "6.1.0-2022-12-29";
  modDirVersion = "6.1.0";

  src = fetchFromGitHub {
    owner = "koverstreet";
    repo = "bcachefs";
    rev = "8f064a4cb5c7cce289b83d7a459e6d8620188b37";
    sha256 = "sha256-UgWAbYToauAjGrgeS+o6N42/oW0roICJIoJlEAHBRPk=";
  };

  kernelPatches = (args.kernelPatches or []) ++ [{
    name = "bcachefs-config";
    patch = null;
    extraConfig = ''
      BCACHEFS_FS m
    '';
  }];
} // (args.argsOverride or {}))
