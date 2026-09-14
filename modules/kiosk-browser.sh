#!/usr/bin/env bash
# Starter Chromium i kiosk for anon. Kaldes af koderup-kiosk-browser.service.
set -euo pipefail

STATE="${KODERUP_KIOSK_STATE:-/run/koderup-kiosk}"
KIOSK_USER="${KODERUP_KIOSK_USER:-anon}"
EXTENSION_DIR="${KODERUP_KIOSK_EXTENSION:?}"
CHROMIUM="${KODERUP_KIOSK_CHROMIUM:?}"

uid="$(id -u "$KIOSK_USER")"
gid="$(id -g "$KIOSK_USER")"
runtime="${XDG_RUNTIME_DIR:-/run/user/$uid}"
url="$(cat "$STATE/url")"
profile="$STATE/profile"
mkdir -p "$profile"
if [[ "$(id -u)" -eq 0 ]]; then
  chown -R "$uid:$gid" "$profile"
fi

wayland_display="${WAYLAND_DISPLAY:-}"
if [[ -z "$wayland_display" ]]; then
  for sock in "$runtime"/wayland-*; do
    [[ -S "$sock" ]] || continue
    wayland_display="$(basename "$sock")"
    break
  done
fi
wayland_display="${wayland_display:-wayland-0}"

xauthority="${XAUTHORITY:-}"
if [[ -z "$xauthority" ]]; then
  for auth in "$runtime"/.mutter-Xwaylandauth.*; do
    [[ -f "$auth" ]] || continue
    xauthority="$auth"
    break
  done
fi

args=(
  --user-data-dir="$profile"
  --kiosk
  --no-first-run
  --disable-infobars
  --noerrdialogs
  --disable-session-crashed-bubble
  --disable-pinch
  --ozone-platform=wayland
  --check-for-update-interval=31536000
)

if [[ -f "$STATE/load-extension" && "$(cat "$STATE/load-extension")" == "1" ]]; then
  args+=(--disable-extensions-except="$EXTENSION_DIR" --load-extension="$EXTENSION_DIR")
fi

args+=("$url")

restart="$(cat "$STATE/browser-restart" 2>/dev/null || echo no)"

run_once() {
  local -a env_args=(
    HOME="/home/$KIOSK_USER"
    USER="$KIOSK_USER"
    LOGNAME="$KIOSK_USER"
    XDG_RUNTIME_DIR="$runtime"
    DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$runtime/bus}"
    XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-wayland}"
    WAYLAND_DISPLAY="$wayland_display"
    DISPLAY="${DISPLAY:-:0}"
  )
  if [[ -n "$xauthority" ]]; then
    env_args+=(XAUTHORITY="$xauthority")
  fi

  if [[ "$(id -u)" -eq 0 ]]; then
    env "${env_args[@]}" runuser -u "$KIOSK_USER" -- "$CHROMIUM" "${args[@]}"
  else
    env "${env_args[@]}" "$CHROMIUM" "${args[@]}"
  fi
}

if [[ "$restart" == "always" ]]; then
  while true; do
    run_once || true
    sleep 0.4
  done
else
  run_once
fi
