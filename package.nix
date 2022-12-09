{ stdenvNoCC, lib }:

let
  inclFiles = {src, name}: files: lib.cleanSourceWith {
    inherit src name;
    filter = _path: _type: _type == "regular" && lib.any (file: builtins.baseNameOf _path == file) files;
  };
in
stdenvNoCC.mkDerivation rec {
  name = "disko";
  src = inclFiles { inherit name; src = ./.; } [
    "disko"
    "cli.nix"
    "default.nix"
    "types.nix"
    "options.nix"
  ];
  installPhase = ''
    mkdir -p $out/bin $out/share/disko
    cp -r $src/* $out/share/disko
    sed \
      -e "s|libexec_dir=\".*\"|libexec_dir=\"$out/share/disko\"|" \
      -e "s|#!/usr/bin/env.*|#!/usr/bin/env bash|" \
      $src/disko > $out/bin/disko
    chmod 755 $out/bin/disko
  '';
  meta = with lib; {
    description = "Format disks with nix-config";
    homepage = "https://github.com/nix-community/disko";
    license = licenses.mit;
    maintainers = with maintainers; [ lassulus ];
    platforms = platforms.linux;
  };
}
