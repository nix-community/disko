{
  lib,
  nixosOptionsDoc,
  runCommand,
  fetchurl,
  pandoc,
}:

let
  diskoLib = import ./lib {
    inherit lib;
    rootMountPoint = "/mnt";
  };
  eval = lib.evalModules {
    modules = [
      {
        options.disko = {
          devices = lib.mkOption {
            type = diskoLib.toplevel;
            default = { };
            description = "The devices to set up";
          };
        };
      }
    ];
  };
  options = nixosOptionsDoc {
    options = eval.options;
  };
  md =
    (runCommand "disko-options.md" { } ''
      cat >$out <<EOF
      # Disko options

      EOF
      cat ${options.optionsCommonMark} >>$out
    '').overrideAttrs
      (_o: {
        # Work around https://github.com/hercules-ci/hercules-ci-agent/issues/168
        allowSubstitutes = true;
      });
  css = fetchurl {
    url = "https://gist.githubusercontent.com/killercup/5917178/raw/40840de5352083adb2693dc742e9f75dbb18650f/pandoc.css";
    sha256 = "sha256-SzSvxBIrylxBF6B/mOImLlZ+GvCfpWNLzGFViLyOeTk=";
  };
in
runCommand "disko.html" { nativeBuildInputs = [ pandoc ]; } ''
  mkdir $out
  cp ${css} $out/pandoc.css
  pandoc --css="pandoc.css" ${md} --to=html5 -s -f markdown+smart --metadata pagetitle="Disko options" -o $out/index.html
''
