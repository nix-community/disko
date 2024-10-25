#!/usr/bin/env nu

use std log

alias nix = ^nix --extra-experimental-features nix-command --extra-experimental-features flakes
alias nix-eval-expr = nix eval --impure --json --expr

def eval-config [args: record]: nothing -> record {
    do { nix-eval-expr $"import ./eval-config.nix \(builtins.fromJSON ''($args | to json -r)'')" }
    | complete
    | if $in.exit_code != 0 {
        {
            success: false
            messages: [
                $"Failed to evaluate disko config with args ($args)!"
                $"Error from nix eval: ($in.stderr)"
            ]
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
            messages: [
                $"File (ansi blue)($config)(ansi reset) does not exist."
            ]
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
            messages: [
                $"Flake-uri ($flakeUri) does not contain an attribute."
                "Please append an attribute like \"#foo\" to the flake-uri."
            ]
        }
    }

    let flake = $parseResult.0.flake | if ($in | path exists) { $in | path expand } else { $in }
    let flakeAttr = $parseResult.0.flakeAttr

    eval-config { flake: $flake, flakeAttr: $flakeAttr }
}

def exit-on-error [context: string] {
    if $in.success {
        log debug $"Success: ($context)"
        log debug $"Return value: ($in.value)"
        return $in.value
    }

    p_err $"Failed to ($context)!"
    for msg in $in.messages {
        print $"(ansi red)│(ansi reset) ($msg)"
    }
    print $"(ansi red)╰────────(ansi reset)"
    exit 1
}

def p_err [msg: string] {
    print $"(ansi bg_red) ERROR: (ansi reset) ($msg)"
}
def p_info [msg: string] {
    print $"(ansi bg_green) INFO:  (ansi reset) ($msg)"
}
def p_help [msg: string] {
    print $"(ansi bg_light_magenta) HELP:  (ansi reset) ($msg)"
}

def modes [] { ["destroy", "format", "mount", "format,mount", "destroy,format,mount"]}

def main [
    mode: string@modes, # Mode to use. Allowed values are 'destroy', 'format', 'mount', 'format,mount', 'destroy,format,mount'
    disko_file?: path, # File to read the disko configuration from. Can be a .nix file or a .json file
    --flake (-f): string # Flake URI to search for the disko configuration
    ]: nothing -> nothing {
    
    if not ($mode in (modes)) {
        p_err $"Invalid mode: (ansi red)($mode)(ansi reset)"
        let valid_modes = modes
            | each { |mode| $"(ansi green)($mode)(ansi reset)" }
            | str join ', '
        p_help $"Valid modes are: ($valid_modes)"
        exit 1
    }

    if not ($flake != null xor $disko_file != null) {
        p_err "Missing arguments!"
        p_help ($"Provide either (ansi magenta_italic)disko_file(ansi reset) as the second argument or " +
            $"(ansi green)--flake(ansi reset)/(ansi green)-f(ansi reset) (ansi magenta_italic)flakeref(ansi reset)")
        exit 1
    }

    let config = if $disko_file != null {
        $disko_file | eval-disko-file | exit-on-error "evaluate config"
    } else {
        $flake | eval-flake | exit-on-error "evaluate flake"
    }

    $config | to json | print
}
