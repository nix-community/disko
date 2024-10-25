use libexec-dir.nu

use std log

alias nix = ^nix --extra-experimental-features nix-command --extra-experimental-features flakes
alias nix-eval-expr = nix eval --impure --json --expr

def eval-config [args: record]: nothing -> record {
    let eval_config_nix = (libexec-dir) + "/lib/eval-config.nix"

    do { nix-eval-expr $"import ($eval_config_nix) \(builtins.fromJSON ''($args | to json -r)'')" }
    | complete
    | if $in.exit_code != 0 {
        {
            success: false
            messages: [ { code: ERR_EVAL_CONFIG_FAILED, details: { args: $args, stderr: $in.stderr } } ]
        }
    } else {
        $in.stdout
        | from json
        | {
            success: true
            value: $in
        }
    }
}

export def eval-disko-file []: path -> record {
    let config = $in

    if not ($config | path exists) {
        return {
            success: false
            messages: [ { code: ERR_FILE_NOT_FOUND, details: { path: $config } } ]
        }
    }

    # If the file is valid JSON, parse and return it
    open $config | try { into record } | if $in != null {
        return {
            success: true
            value: $in
        }
    }

    eval-config { diskoFile: $config }
}

export def eval-flake []: string -> record {
    let flakeUri = $in
    let parseResult = $flakeUri | parse "{flake}#{flakeAttr}" | if not ( $in | is-empty ) {
        $in
    } else {
        return {
            success: false
            messages: [ { code: ERR_FLAKE_URI_NO_ATTRIBUTE, details: { flakeUri: $flakeUri } } ]
        }
    }

    let flake = $parseResult.0.flake | if ($in | path exists) { $in | path expand } else { $in }
    let flakeAttr = $parseResult.0.flakeAttr

    eval-config { flake: $flake, flakeAttr: $flakeAttr }
}
