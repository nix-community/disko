{ coreutils, gnused, lib }:

let
  inclFiles = {src, name}: files: lib.cleanSourceWith {
    inherit src name;
    filter = _path: _type: _type == "regular" && lib.any (file: builtins.baseNameOf _path == file) files;
  };
in
derivation rec {
  system = "x86_64-linux";
  name = "disko";
  builder = "/bin/sh";
  PATH    = "${coreutils}/bin:${gnused}/bin";
  passAsFile = ["buildPhase"];
  buildPhase = ''
    mkdir -p $out/bin $out/share/disko
    cp -r $src/* $out/share/disko
    sed \
      -e "s|libexec_dir=\".*\"|libexec_dir=\"$out/share/disko\"|" \
      -e "s|#!/usr/bin/env.*|#!/usr/bin/env bash|" \
      $src/disko > $out/bin/disko
    chmod 755 $out/bin/disko
  '';
  args = ["-c" ". $buildPhasePath"];
  src = inclFiles { inherit name; src = ./.; } [
    "disko"
    "cli.nix"
    "default.nix"
    "types.nix"
    "options.nix"
  ];
} // {
  meta.description = "Format disks with nix-config";
}
