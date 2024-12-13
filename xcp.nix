{
  rustPlatform,
  fetchFromGitHub,
  lib,
  xcp,
}:
if lib.versionAtLeast xcp.version "0.22.0" then
  xcp
else
  rustPlatform.buildRustPackage rec {
    pname = "xcp";
    version = "0.22.0";

    src = fetchFromGitHub {
      owner = "tarka";
      repo = pname;
      rev = "v${version}";
      hash = "sha256-3Y8/zRdWD6GSkhp1UabGyDrU62h1ZADYd4D1saED1ug=";
    };

    # no such file or directory errors
    doCheck = false;

    cargoHash = "sha256-08Yw0HOaV8XKwzrODaBcHato6TfKBeVBa55MWzINAE0=";

    inherit (xcp) meta;
  }
