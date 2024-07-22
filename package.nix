{ stdenvNoCC, makeWrapper, lib, path, nix, coreutils, nixos-install-tools }:

stdenvNoCC.mkDerivation (finalAttrs: {
  name = "disko";
  src = ./.;
  nativeBuildInputs = [
    makeWrapper
  ];
  installPhase = ''
    mkdir -p $out/bin $out/share/disko
    cp -r install-cli.nix cli.nix default.nix disk-deactivate lib $out/share/disko

    for i in disko disko-install; do
      sed -e "s|libexec_dir=\".*\"|libexec_dir=\"$out/share/disko\"|" "$i" > "$out/bin/$i"
      chmod 755 "$out/bin/$i"
      wrapProgram "$out/bin/$i" \
        --prefix PATH : ${lib.makeBinPath [ nix coreutils nixos-install-tools ]} \
        --prefix NIX_PATH : "nixpkgs=${path}"
    done
  '';
  meta = with lib; {
    description = "Format disks with nix-config";
    homepage = "https://github.com/nix-community/disko";
    license = licenses.mit;
    maintainers = with maintainers; [ lassulus ];
    platforms = platforms.linux;
    mainProgram = finalAttrs.name;
  };
})
