{ lib ? import <nixpkgs/lib>
, rootMountPoint ? "/mnt"
}:
let
  types = import ./types { inherit lib rootMountPoint; };
  eval = cfg: lib.evalModules {
    modules = lib.singleton {
      # _file = toString input;
      imports = lib.singleton { devices = cfg; };
      options = {
        devices = lib.mkOption {
          type = types.devices;
        };
      };
    };
  };
in
{
  types = types;
  create = cfg: types.diskoLib.create (eval cfg).config.devices;
  createScript = cfg: pkgs: pkgs.writeScript "disko-create" ''
    #!/usr/bin/env bash
    export PATH=${lib.makeBinPath (types.diskoLib.packages (eval cfg).config.devices pkgs)}:$PATH
    ${types.diskoLib.create (eval cfg).config.devices}
  '';
  createScriptNoDeps = cfg: pkgs: pkgs.writeScript "disko-create" ''
    #!/usr/bin/env bash
    ${types.diskoLib.create (eval cfg).config.devices}
  '';
  mount = cfg: types.diskoLib.mount (eval cfg).config.devices;
  mountScript = cfg: pkgs: pkgs.writeScript "disko-mount" ''
    #!/usr/bin/env bash
    export PATH=${lib.makeBinPath (types.diskoLib.packages (eval cfg).config.devices pkgs)}:$PATH
    ${types.diskoLib.mount (eval cfg).config.devices}
  '';
  mountScriptNoDeps = cfg: pkgs: pkgs.writeScript "disko-mount" ''
    #!/usr/bin/env bash
    ${types.diskoLib.mount (eval cfg).config.devices}
  '';
  zapCreateMount = cfg: types.diskoLib.zapCreateMount (eval cfg).config.devices;
  zapCreateMountScript = cfg: pkgs: pkgs.writeScript "disko-zap-create-mount" ''
    #!/usr/bin/env bash
    export PATH=${lib.makeBinPath (types.diskoLib.packages (eval cfg).config.devices pkgs)}:$PATH
    ${types.diskoLib.zapCreateMount (eval cfg).config.devices}
  '';
  zapCreateMountScriptNoDeps = cfg: pkgs: pkgs.writeScript "disko-zap-create-mount" ''
    #!/usr/bin/env bash
    ${types.diskoLib.zapCreateMount (eval cfg).config.devices}
  '';
  config = cfg: { imports = types.diskoLib.config (eval cfg).config.devices; };
  packages = cfg: types.diskoLib.packages (eval cfg).config.devices;
}
