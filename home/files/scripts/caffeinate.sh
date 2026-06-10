#!/usr/bin/env bash

set -euo pipefail

UNIT="caffeinate.service"

if systemctl --user is-active --quiet "$UNIT"; then
  systemctl --user stop "$UNIT"
  notify-send "Caffeinate" "Disabled — lid close and idle suspend restored"
else
  systemd-run --user --unit="$UNIT" --collect \
    --description="Inhibit lid-close and idle suspend" \
    systemd-inhibit \
    --what=handle-lid-switch:idle \
    --who=caffeinate \
    --why="Stay awake with lid closed / screen off" \
    --mode=block \
    sleep infinity >/dev/null
  notify-send "Caffeinate" "Enabled — lid close and idle suspend disabled until toggled off"
fi
