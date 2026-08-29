#!/usr/bin/env bash
# Post-upgrade hooks for managed laptops. Runs after a successful nixos-upgrade.
set -euo pipefail

# Reset Dash so dconf defaults (favorite-apps) take effect for the logged-in user.
uid=$(id -u anon)
runtime=/run/user/"$uid"
if [ -S "$runtime/bus" ]; then
  env DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus" XDG_RUNTIME_DIR="$runtime" \
    runuser -u anon -- dconf reset /org/gnome/shell/favorite-apps
else
  runuser -u anon -- dbus-run-session -- dconf reset /org/gnome/shell/favorite-apps
fi

# Add further post-upgrade commands below.
