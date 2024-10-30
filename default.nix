{ lib ? import <nixpkgs/lib>
, rootMountPoint ? "/mnt"
, checked ? false
, diskoLib ? import ./src/disko_lib { inherit lib rootMountPoint; }
}:
diskoLib.outputs {
  inherit lib checked rootMountPoint;
}
