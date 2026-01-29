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

# Compositor
if [ -f "$HOME/.config/picom/picom.conf" ]; then
  run picom --config "$HOME/.config/picom/picom.conf" -b
else
  run picom -b
fi

# Audio tray
run pasystray

# Polkit agent
run polkit-gnome-authentication-agent-1

# Keyring
run dbus-update-activation-environment --all
run gnome-keyring-daemon --start --components=secrets,ssh,pkcs11
