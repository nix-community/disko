#!/usr/bin/env python3
# ANSI escape sequences for coloring and formatting text
# Inspired by rene-d's colors.py, published in 2018
# See https://gist.github.com/rene-d/9e584a7dd2935d0f461904b9f2950007

import sys


class Colors:
    """
    ANSI escape sequences
    These constants were generated using nushell with the following command:

    nix run nixpkgs#nushell -- -c '
        ansi -l
        | where name !~ "^xterm"
        | each { |line|
            $'"'"'($line.name | str upcase) = "($line.code  | str replace "\\e" "\\033")"'"'"'
        }
        | print -r'

    I then removed many useless codes that are related to cursor movement, clearing the screen, etc.
    """

    GREEN = "\033[32m"
    GREEN_BOLD = "\033[1;32m"
    GREEN_ITALIC = "\033[3;32m"
    GREEN_DIMMED = "\033[2;32m"
    GREEN_REVERSE = "\033[7;32m"
    BG_GREEN = "\033[42m"
    LIGHT_GREEN = "\033[92m"
    LIGHT_GREEN_BOLD = "\033[1;92m"
    LIGHT_GREEN_UNDERLINE = "\033[4;92m"
    LIGHT_GREEN_ITALIC = "\033[3;92m"
    LIGHT_GREEN_DIMMED = "\033[2;92m"
    LIGHT_GREEN_REVERSE = "\033[7;92m"
    BG_LIGHT_GREEN = "\033[102m"
    RED = "\033[31m"
    RED_BOLD = "\033[1;31m"
    RED_UNDERLINE = "\033[4;31m"
    RED_ITALIC = "\033[3;31m"
    RED_DIMMED = "\033[2;31m"
    RED_REVERSE = "\033[7;31m"
    BG_RED = "\033[41m"
    LIGHT_RED = "\033[91m"
    LIGHT_RED_BOLD = "\033[1;91m"
    LIGHT_RED_UNDERLINE = "\033[4;91m"
    LIGHT_RED_ITALIC = "\033[3;91m"
    LIGHT_RED_DIMMED = "\033[2;91m"
    LIGHT_RED_REVERSE = "\033[7;91m"
    BG_LIGHT_RED = "\033[101m"
    BLUE = "\033[34m"
    BLUE_BOLD = "\033[1;34m"
    BLUE_UNDERLINE = "\033[4;34m"
    BLUE_ITALIC = "\033[3;34m"
    BLUE_DIMMED = "\033[2;34m"
    BLUE_REVERSE = "\033[7;34m"
    BG_BLUE = "\033[44m"
    LIGHT_BLUE = "\033[94m"
    LIGHT_BLUE_BOLD = "\033[1;94m"
    LIGHT_BLUE_UNDERLINE = "\033[4;94m"
    LIGHT_BLUE_ITALIC = "\033[3;94m"
    LIGHT_BLUE_DIMMED = "\033[2;94m"
    LIGHT_BLUE_REVERSE = "\033[7;94m"
    BG_LIGHT_BLUE = "\033[104m"
    BLACK = "\033[30m"
    BLACK_BOLD = "\033[1;30m"
    BLACK_UNDERLINE = "\033[4;30m"
    BLACK_ITALIC = "\033[3;30m"
    BLACK_DIMMED = "\033[2;30m"
    BLACK_REVERSE = "\033[7;30m"
    BG_BLACK = "\033[40m"
    LIGHT_GRAY = "\033[97m"
    LIGHT_GRAY_BOLD = "\033[1;97m"
    LIGHT_GRAY_UNDERLINE = "\033[4;97m"
    LIGHT_GRAY_ITALIC = "\033[3;97m"
    LIGHT_GRAY_DIMMED = "\033[2;97m"
    LIGHT_GRAY_REVERSE = "\033[7;97m"
    BG_LIGHT_GRAY = "\033[107m"
    YELLOW = "\033[33m"
    YELLOW_BOLD = "\033[1;33m"
    YELLOW_UNDERLINE = "\033[4;33m"
    YELLOW_ITALIC = "\033[3;33m"
    YELLOW_DIMMED = "\033[2;33m"
    YELLOW_REVERSE = "\033[7;33m"
    BG_YELLOW = "\033[43m"
    LIGHT_YELLOW = "\033[93m"
    LIGHT_YELLOW_BOLD = "\033[1;93m"
    LIGHT_YELLOW_UNDERLINE = "\033[4;93m"
    LIGHT_YELLOW_ITALIC = "\033[3;93m"
    LIGHT_YELLOW_DIMMED = "\033[2;93m"
    LIGHT_YELLOW_REVERSE = "\033[7;93m"
    BG_LIGHT_YELLOW = "\033[103m"
    PURPLE = "\033[35m"
    PURPLE_BOLD = "\033[1;35m"
    PURPLE_UNDERLINE = "\033[4;35m"
    PURPLE_ITALIC = "\033[3;35m"
    PURPLE_DIMMED = "\033[2;35m"
    PURPLE_REVERSE = "\033[7;35m"
    BG_PURPLE = "\033[45m"
    LIGHT_PURPLE = "\033[95m"
    LIGHT_PURPLE_BOLD = "\033[1;95m"
    LIGHT_PURPLE_UNDERLINE = "\033[4;95m"
    LIGHT_PURPLE_ITALIC = "\033[3;95m"
    LIGHT_PURPLE_DIMMED = "\033[2;95m"
    LIGHT_PURPLE_REVERSE = "\033[7;95m"
    BG_LIGHT_PURPLE = "\033[105m"
    MAGENTA = "\033[35m"
    MAGENTA_BOLD = "\033[1;35m"
    MAGENTA_UNDERLINE = "\033[4;35m"
    MAGENTA_ITALIC = "\033[3;35m"
    MAGENTA_DIMMED = "\033[2;35m"
    MAGENTA_REVERSE = "\033[7;35m"
    BG_MAGENTA = "\033[45m"
    LIGHT_MAGENTA = "\033[95m"
    LIGHT_MAGENTA_BOLD = "\033[1;95m"
    LIGHT_MAGENTA_UNDERLINE = "\033[4;95m"
    LIGHT_MAGENTA_ITALIC = "\033[3;95m"
    LIGHT_MAGENTA_DIMMED = "\033[2;95m"
    LIGHT_MAGENTA_REVERSE = "\033[7;95m"
    BG_LIGHT_MAGENTA = "\033[105m"
    CYAN = "\033[36m"
    CYAN_BOLD = "\033[1;36m"
    CYAN_UNDERLINE = "\033[4;36m"
    CYAN_ITALIC = "\033[3;36m"
    CYAN_DIMMED = "\033[2;36m"
    CYAN_REVERSE = "\033[7;36m"
    BG_CYAN = "\033[46m"
    LIGHT_CYAN = "\033[96m"
    LIGHT_CYAN_BOLD = "\033[1;96m"
    LIGHT_CYAN_UNDERLINE = "\033[4;96m"
    LIGHT_CYAN_ITALIC = "\033[3;96m"
    LIGHT_CYAN_DIMMED = "\033[2;96m"
    LIGHT_CYAN_REVERSE = "\033[7;96m"
    BG_LIGHT_CYAN = "\033[106m"
    WHITE = "\033[37m"
    WHITE_BOLD = "\033[1;37m"
    WHITE_UNDERLINE = "\033[4;37m"
    WHITE_ITALIC = "\033[3;37m"
    WHITE_DIMMED = "\033[2;37m"
    WHITE_REVERSE = "\033[7;37m"
    BG_WHITE = "\033[47m"
    DARK_GRAY = "\033[90m"
    DARK_GRAY_BOLD = "\033[1;90m"
    DARK_GRAY_UNDERLINE = "\033[4;90m"
    DARK_GRAY_ITALIC = "\033[3;90m"
    DARK_GRAY_DIMMED = "\033[2;90m"
    DARK_GRAY_REVERSE = "\033[7;90m"
    BG_DARK_GRAY = "\033[100m"
    DEFAULT = "\033[39m"
    DEFAULT_BOLD = "\033[1;39m"
    DEFAULT_UNDERLINE = "\033[4;39m"
    DEFAULT_ITALIC = "\033[3;39m"
    DEFAULT_DIMMED = "\033[2;39m"
    DEFAULT_REVERSE = "\033[7;39m"
    BG_DEFAULT = "\033[49m"
    RESET = "\033[0m"
    ATTR_NORMAL = "\033[0m"
    ATTR_BOLD = "\033[1m"
    ATTR_DIMMED = "\033[2m"
    ATTR_ITALIC = "\033[3m"
    ATTR_UNDERLINE = "\033[4m"
    ATTR_BLINK = "\033[5m"
    ATTR_HIDDEN = "\033[8m"
    ATTR_STRIKE = "\033[9m"

    # cancel SGR codes if we don't write to a terminal
    if not sys.stdout.isatty():
        for _ in dir():
            if isinstance(_, str) and _[0] != "_":
                locals()[_] = ""  # type: ignore[misc]
    else:
        import platform

        # set Windows console in VT mode
        if platform.system() == "Windows":
            import ctypes

            kernel32 = ctypes.windll.kernel32  # type: ignore[attr-defined, misc]
            kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)  # type: ignore[misc]
            del kernel32
