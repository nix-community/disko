{ python3Packages, lib, lix, coreutils, nixos-install-tools, binlore, diskoVersion }:

let
  self = python3Packages.buildPythonApplication {
    pname = "disko2";
    version = diskoVersion;
    src = ./.;
    pyproject = true;

    build-system = [ python3Packages.setuptools ];
    dependencies = [
      lix # lix instead of nix because it produces way better eval errors
      coreutils
      nixos-install-tools
    ];

    # Otherwise resholve thinks that disko and disko-install might be able to execute their arguments
    passthru.binlore.out = binlore.synthesize self ''
      execer cannot bin/.disko2-wrapped
    '';
    postInstall = ''
      mkdir -p $out/share/disko/
      cp example/simple-efi.nix $out/share/disko/
    '';

    makeWrapperArgs = [ "--set DISKO_VERSION ${diskoVersion}" ];

    doCheck = true;
    # installCheckPhase = ''
    #   $out/bin/disko2 mount $out/share/disko/simple-efi.nix
    # '';
    meta = with lib; {
      description = "Format disks with nix-config";
      homepage = "https://github.com/nix-community/disko";
      license = licenses.mit;
      maintainers = with maintainers; [ lassulus ];
      platforms = platforms.linux;
      mainProgram = "disko2";
    };
  };
in
self
