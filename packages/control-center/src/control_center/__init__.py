"""Control Center package.

Importing this package has a side effect: it sets ``GDK_BACKEND`` and
preloads ``libgtk4-layer-shell`` so the first ``gi.require_version`` calls
succeed. Submodules can then freely ``from gi.repository import ...``.
"""

import ctypes
import os

os.environ["GDK_BACKEND"] = "wayland"

_gls = os.environ.get("GTK4_LAYER_SHELL_LIB", "")
if _gls:
    ctypes.CDLL(_gls, mode=ctypes.RTLD_GLOBAL)

import gi  # noqa: E402

gi.require_version("Gtk4LayerShell", "1.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gtk", "4.0")
