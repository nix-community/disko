{ stdenvNoCC, makeWrapper, lib, path }:

stdenvNoCC.mkDerivation rec {
  name = "disko";
  src = ./.;
  nativeBuildInputs = [
    makeWrapper
  ];
  installPhase = ''
    mkdir -p $out/bin $out/share/disko
    cp -r cli.nix default.nix types.nix disk-deactivate types $out/share/disko
    sed \
      -e "s|libexec_dir=\".*\"|libexec_dir=\"$out/share/disko\"|" \
      -e "s|#!/usr/bin/env.*|#!/usr/bin/env bash|" \
      disko > $out/bin/disko
    chmod 755 $out/bin/disko
    wrapProgram $out/bin/disko --prefix NIX_PATH : "nixpkgs=${path}"
  '';
  meta = with lib; {
    description = "Format disks with nix-config";
    homepage = "https://github.com/nix-community/disko";
    license = licenses.mit;
    maintainers = with maintainers; [ lassulus ];
    platforms = platforms.linux;
  };
}
