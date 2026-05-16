"""Entry point: parse argv, take the single-instance lock, hand off to GTK."""

import os
import signal
import sys

from gi.repository import GLib

from .app import ControlCenter
from .constants import VIEWS
from .gather import _default_state, gather_fast_state
from .state_file import (
    acquire_lock,
    clear_state,
    process_alive,
    read_state,
    release_lock,
    write_state,
)
from .theme import load_colors


def main():
    initial = "home"
    if len(sys.argv) == 2:
        arg = sys.argv[1]
        if arg in VIEWS:
            initial = arg
        elif arg in ("-h", "--help"):
            print(f"usage: control-center [{'|'.join(VIEWS)}]")
            return 0
        else:
            print(f"usage: control-center [{'|'.join(VIEWS)}]", file=sys.stderr)
            return 2
    elif len(sys.argv) > 2:
        print(f"usage: control-center [{'|'.join(VIEWS)}]", file=sys.stderr)
        return 2

    acquire_lock()
    state = read_state()
    pid = state.get("pid")
    current = state.get("view")
    if isinstance(pid, int) and process_alive(pid):
        os.kill(pid, signal.SIGTERM)
        if current == initial:
            clear_state(pid)
            release_lock()
            return 0
        for _ in range(20):
            if not process_alive(pid):
                break
            GLib.usleep(25_000)

    write_state(os.getpid(), initial)
    release_lock()
    initial_state = _default_state()
    try:
        initial_state = gather_fast_state(initial_state)
    except Exception:
        pass
    app = ControlCenter(initial, load_colors(), initial_state)
    return app.run(None)
