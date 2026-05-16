"""Subprocess helper shared by state-gathering and action modules."""

import subprocess


def _run(cmd, timeout=1.5):
    """Run a command, return (stdout, ok)."""
    try:
        r = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout
        )
        return r.stdout, r.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return "", False
