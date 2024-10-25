#!/usr/bin/env nu

use lib [eval-disko-file eval-flake p_err p_help exit-on-error]

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
