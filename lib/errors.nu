use std log

# Color definitions. NOTE: Sort them alphabetically when adding new ones!
def command [] { ansi cyan_italic } # Commands that were run or can be run
def file [] { ansi blue } # File paths
def flag [] { ansi green } # Command line flags (like --version or -f)
def invalid [] { ansi red } # Invalid values
def placeholder [] { ansi magenta_italic } # Values that need to be replaced
def value [] { ansi green } # Values that are allowed

def reset [] { ansi reset } # Shortcut to reset the color

def "lookup ERR_INVALID_MODE" [mode: string, valid_modes: list] {
    let valid_modes = modes
        | each { |mode| $"(value)($mode)(reset)" }
        | str join ', '

    [
        {
            type: error
            msg: $"Invalid mode: (invalid)($mode)(reset)"
        }
        { 
            type: help
            msg: $"Valid modes are:\n($valid_modes)"
        }
    ]
}

def "lookup ERR_MISSING_ARGUMENTS" [] {
    [
        {
            type: error
            msg: $"Missing arguments!"
        }
        {
            type: help
            msg: ($"Provide either (placeholder)disko_file(reset) as the second argument or " +
                  $"(flag)--flake(reset)/(flag)-f(reset) (placeholder)flakeref(reset)")
        }
    ]
}

def "lookup ERR_EVAL_CONFIG_FAILED" [ args, stderr ] {
    [
        {
            type: error 
            msg: ($"Failed to evaluate disko config with args (invalid)($args)(reset)!\n" +
                  $"Output from `(command)nix eval(reset)`: ($stderr)")

        }
    ]
}

def "lookup ERR_FILE_NOT_FOUND" [ path ] {
    [
        {
            type: error
            msg: ($"File (file)($path)(reset) does not exist.")
        }
    ]
}

def "lookup ERR_FLAKE_URI_NO_ATTRIBUTE" [ flakeUri ] {
    [
        {
            type: error
            msg: ($"Flake URI (invalid)($flakeUri)(reset) does not contain an attribute.")
        }
        {
            type: help
            msg:  $"Append an attribute like (value)#(placeholder)foo(reset) to the flake URI."
        }
    ]
}

def lookup-message []: record<code: string, details: record<any>> -> list<record<type: string, msg: string>> {
    let code = $in.code
    let details = $in.details? # Not all errors have details
    match $code {
        ERR_INVALID_MODE => (lookup ERR_INVALID_MODE $details.mode $details.valid_modes)
        ERR_MISSING_ARGUMENTS => (lookup ERR_MISSING_ARGUMENTS)
        ERR_EVAL_CONFIG_FAILED => (lookup ERR_EVAL_CONFIG_FAILED $details.args $details.stderr)
        ERR_FILE_NOT_FOUND => (lookup ERR_FILE_NOT_FOUND $details.path)
        ERR_FLAKE_URI_NO_ATTRIBUTE => (lookup ERR_FLAKE_URI_NO_ATTRIBUTE $details.flakeUri)
        _ => [
            {
                type: error
                msg: $"Unknown error code: (invalid)($code)(reset)."
            }
            {
                type: info
                msg: $"The following details were provided:\n($details)"
            }
            {
                type: help
                msg: $"Please report this issue, this should never happen!"
            }
        ]
    }
}

def render-message []: record<type: string, msg: string> -> nothing {
    let type = $in.type
    let msg_lines = $in.msg | lines

    let bg_color = match $type {
        error => (ansi bg_red)
        help => (ansi bg_light_magenta)
        info => (ansi bg_green)
    }
    let color = match $type {
        error => (ansi red)
        help => (ansi light_magenta)
        info => (ansi green)
    }
    let title = match $type {
        error => "ERROR"
        help => " HELP"
        info => " INFO"
    }

    if ($msg_lines | length) == 1 {
        print $"  ($bg_color) ($title): (reset) ($msg_lines.0)"
        return
    }

    print $"($color)╭─($bg_color) ($title): (reset) ($msg_lines.0)"

    for line in ($msg_lines | skip 1) {
        print $"($color)│  (reset)($line)"
    }

    print $"($color)╰─────────(reset)"
}

def print-message []: record -> nothing {
    $in | lookup-message | each { render-message }
}

export def exit-on-error [context: string]: record -> any {
    let result = $in
    if $result.success {
        log debug $"Success: ($context)"
        log debug $"Return value: ($result.value)"
        return $result.value
    } else {
        log debug $"Failure: ($context)"
    }

    for message in $in.messages {
        $message | print-message
    }
    exit 1
}

# Info and help messages may be printed directly, but errors not! That's why we don't have p-err here.
export def print-info []: string -> nothing {
    { type: info, msg: $in } | render-message
}
export def print-help []: string -> nothing {
    { type: help, msg: $in } | render-message
}