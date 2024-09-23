{ stdenvNoCC, makeWrapper, lib, path, nix, coreutils, nixos-install-tools, fetchpatch, xcp }:

let
  xcp' = xcp.overrideAttrs (old: {
    # https://github.com/tarka/xcp/pull/56
    patches = (old.patches or []) ++ [
      (fetchpatch {
        url = "https://github.com/tarka/xcp/commit/8c00cef85c4ae6ffa4f49a59e5f64f68f6407000.patch";
        sha256 = "sha256-pwgtA/36YPRtpn4jmOcb44xjiDfEKmpXdJDSvqfGQuk=";
      })
    ];
  });
in
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
        --prefix PATH : ${lib.makeBinPath [ nix coreutils nixos-install-tools xcp' ]} \
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
