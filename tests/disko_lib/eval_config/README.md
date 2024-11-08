# eval_config.py tests

If you change something about the evaluation and need to update one of the
result files here, you can run a command like this:

    ./disko2 dev eval example/simple-efi.nix > tests/disko_lib/eval_config/file-simple-efi-result.json

Change the paths depending on the example whose evaluation result changed.

If you're thinking "this sounds like snapshots to me" and "isn't there a pytest plugin for this?",
then you'd be correct, but [pytest-insta](https://github.com/vberlier/pytest-insta) is not packaged
in nixpkgs at the time of writing (2024-11-08).

If you're reading this, and you
[search nixpkgs for "pytest-insta"](https://search.nixos.org/packages?channel=unstable&query=pytest-insta)
AND this returns the `pytest-insta` package (or there is a new, better snapshotting plugin for pytest),
please open an issue so we can replace this manual process with it!