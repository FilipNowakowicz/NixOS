#!/usr/bin/env bash

run() {
  if ! pgrep -f "$1" >/dev/null; then
    "$@" &
  fi
}

computer_type=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo "")

# Laptop extras
if [ "$computer_type" = "8" ] || [ "$computer_type" = "9" ] || [ "$computer_type" = "10" ]; then
  run nm-applet
  run cbatticon
fi

# Compositor (optional – comment out if you don’t want it). Use the user's
# picom configuration if it exists.
if [ -f "$HOME/.config/picom/picom.conf" ]; then
  run picom --config "$HOME/.config/picom/picom.conf" -b
else
  run picom -b
fi

# Audio tray
run pasystray

# Polkit agent
run /usr/lib/xfce-polkit/xfce-polkit

# Keyring
run dbus-update-activation-environment --all
run gnome-keyring-daemon --start --components=secrets

