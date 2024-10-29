import subprocess

from lib.logging import debug
from lib.result import DiskoError, DiskoResult, DiskoSuccess


def run(args: list[str]) -> DiskoResult[str]:
    command = " ".join(args)
    debug(f"Running: {command}")

    result = subprocess.run(args, capture_output=True, text=True)

    debug(
        f"""
        Ran: {command}
        Exit code: {result.returncode}
        Stdout: {result.stdout}
        Stderr: {result.stderr}
        """
    )

    if result.returncode == 0:
        return DiskoSuccess(result.stdout, "run command")

    return DiskoError.single_message(
        "ERR_COMMAND_FAILED",
        {
            "command": command,
            "stderr": result.stderr,
            "exit_code": result.returncode,
        },
        "run command",
    )
