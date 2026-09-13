#!/usr/bin/env bash
# Starter Chromium i kiosk for anon. Kaldes af koderup-kiosk-browser.service.
set -euo pipefail

STATE="${KODERUP_KIOSK_STATE:-/run/koderup-kiosk}"
KIOSK_USER="${KODERUP_KIOSK_USER:-anon}"
EXTENSION_DIR="${KODERUP_KIOSK_EXTENSION:?}"
CHROMIUM="${KODERUP_KIOSK_CHROMIUM:?}"

uid="$(id -u "$KIOSK_USER")"
runtime="/run/user/$uid"
url="$(cat "$STATE/url")"
profile="$STATE/profile"
mkdir -p "$profile"
chown -R "$KIOSK_USER":"$KIOSK_USER" "$profile"

args=(
  --user-data-dir="$profile"
  --kiosk
  --no-first-run
  --disable-infobars
  --noerrdialogs
  --disable-session-crashed-bubble
  --disable-pinch
  --ozone-platform-hint=auto
  --check-for-update-interval=31536000
)

if [[ -f "$STATE/load-extension" && "$(cat "$STATE/load-extension")" == "1" ]]; then
  args+=(--disable-extensions-except="$EXTENSION_DIR" --load-extension="$EXTENSION_DIR")
fi

args+=("$url")

# Genstart-loop hvis close er blokeret
restart="$(cat "$STATE/browser-restart" 2>/dev/null || echo no)"

run_once() {
  env \
    HOME="/home/$KIOSK_USER" \
    USER="$KIOSK_USER" \
    LOGNAME="$KIOSK_USER" \
    XDG_RUNTIME_DIR="$runtime" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus" \
    DISPLAY="${DISPLAY:-:0}" \
    WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
    runuser -u "$KIOSK_USER" -- "$CHROMIUM" "${args[@]}"
}

if [[ "$restart" == "always" ]]; then
  while true; do
    run_once || true
    sleep 0.4
  done
else
  run_once
fi
