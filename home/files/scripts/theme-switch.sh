#!/bin/bash
set -euo pipefail

THEME="${1:-}"
THEMES_DIR="$HOME/.config/themes"
ACTIVE_FILE="$NIX_REPO/home/theme/active.nix"

# Get current theme from active.nix
if [[ -f $ACTIVE_FILE ]]; then
  CURRENT_THEME=$(grep -oP 'themes/\K[^.]+' "$ACTIVE_FILE" 2>/dev/null || echo "unknown")
else
  CURRENT_THEME="unknown"
fi

# List available themes if no argument
if [[ -z $THEME ]]; then
  echo "Available themes:"
  for dir in "$THEMES_DIR"/*; do
    [[ -d $dir ]] && basename "$dir"
  done | sort
  echo ""
  echo "Current theme: $CURRENT_THEME"
  echo ""
  echo "Usage: theme-switch <theme-name>"
  exit 0
fi

# Validate theme exists
if [[ ! -d "$THEMES_DIR/$THEME" ]]; then
  echo "Error: Theme not found: $THEME"
  echo "Available themes:"
  for dir in "$THEMES_DIR"/*; do
    [[ -d $dir ]] && basename "$dir"
  done | sort
  exit 1
fi

# Check if already active
if [[ $CURRENT_THEME == "$THEME" ]]; then
  echo "Theme '$THEME' is already active"
  exit 0
fi

# Update active.nix
if [[ ! -f $ACTIVE_FILE ]]; then
  echo "Error: $ACTIVE_FILE not found"
  exit 1
fi

echo "import ./themes/$THEME.nix" >"$ACTIVE_FILE"
echo "Updated active.nix to $THEME"

# Symlink new theme configs into live app paths
ln -sf "$THEMES_DIR/$THEME/kitty-theme.conf" "$HOME/.config/kitty/current-theme.conf"
ln -sf "$THEMES_DIR/$THEME/hypr-colors.conf" "$HOME/.config/hypr/colors.conf"
ln -sf "$THEMES_DIR/$THEME/hyprlock-colors.conf" "$HOME/.config/hypr/hyprlock-colors.conf"
ln -sf "$THEMES_DIR/$THEME/waybar-colors.css" "$HOME/.config/waybar/colors.css"
ln -sf "$THEMES_DIR/$THEME/mako-config" "$HOME/.config/mako/config"
ln -sf "$THEMES_DIR/$THEME/wallpaper" "$HOME/.local/share/wallpapers/current.png"

# Reload apps
hyprctl reload >/dev/null 2>&1 || true

pkill waybar || true
sleep 0.3
waybar &

pkill swaybg || true
sleep 0.2
swaybg -m fill -i "$HOME/.local/share/wallpapers/current.png" &

for socket in /tmp/kitty-*/kitty-*; do
  [[ -S $socket ]] && kitty @ --to "unix:$socket" load-config 2>/dev/null || true
done

pkill mako || true
sleep 0.5
systemctl --user restart mako.service 2>/dev/null || true

notify-send "Theme changed" "Switched to: $THEME" || true
echo "✓ Theme switched to $THEME"
