from disko_lib.ansi import Colors


# Color definitions. Note: Sort them alphabetically when adding new ones!
COMMAND = Colors.CYAN_ITALIC  # Commands that were run or can be run
EM = Colors.WHITE_ITALIC  # Emphasized text
EM_WARN = Colors.YELLOW_ITALIC  # Emphasized text that is a warning
FILE = Colors.BLUE  # File paths
FLAG = Colors.GREEN  # Command line flags (like --version or -f)
INVALID = Colors.RED  # Invalid values
PLACEHOLDER = Colors.MAGENTA_ITALIC  # Values that need to be replaced
VALUE = Colors.GREEN  # Values that are allowed

RESET = Colors.RESET  # Shortcut to reset the color
