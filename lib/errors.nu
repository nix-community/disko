use std log

export def exit-on-error [context: string] {
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

export def p_err [msg: string] {
    print $"(ansi bg_red) ERROR: (ansi reset) ($msg)"
}
export def p_info [msg: string] {
    print $"(ansi bg_green) INFO:  (ansi reset) ($msg)"
}
export def p_help [msg: string] {
    print $"(ansi bg_light_magenta) HELP:  (ansi reset) ($msg)"
}