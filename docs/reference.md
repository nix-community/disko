# Reference Manual: disko

## Module Options

TODO: Still to be documented

## # Reference Manual: disko

## Command Line Options

```
$ nix run github:nix-community/disko --
disko [options] disk-config.nix
or disko [options] --flake github:somebody/somewhere
Options:
* -m, --mode mode
  set the mode, either create or mount
* -f, --flake uri
  fetch the disko config relative to this flake's root
* --arg name value
  pass value to nix-build. can be used to set disk-names for example
* --argstr name value
  pass value to nix-build as string
* --root-mountpoint /mnt
  where to mount the device tree
* --dry-run
  just show the path to the script instead of running it
* --debug
  run with set -x
```

##
