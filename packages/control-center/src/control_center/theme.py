"""Waybar color palette parser used by both the CSS builder and the app."""

import os
import re

from .constants import DEFAULTS


def load_colors():
    colors = dict(DEFAULTS)
    path = os.path.expanduser("~/.config/waybar/colors.css")
    try:
        with open(path) as f:
            for line in f:
                m = re.match(r"@define-color\s+(\w+)\s+#([0-9a-fA-F]{6})", line)
                if m:
                    colors[m.group(1)] = m.group(2)
    except OSError:
        pass
    return colors


def h2rgb(h):
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))
