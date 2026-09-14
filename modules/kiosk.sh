#!/usr/bin/env bash
# koderup-kiosk — start/stop Chromium-kiosk på anon's GNOME-session.
set -euo pipefail

STATE="${KODERUP_KIOSK_STATE:-/run/koderup-kiosk}"
PAGE_PORT="${KODERUP_KIOSK_PORT:-4173}"
DEMO_URL="http://127.0.0.1:${PAGE_PORT}/"
KIOSK_USER="${KODERUP_KIOSK_USER:-anon}"

# Escape-id'er (rækkefølge bruges af randomizer og status).
ESCAPES=(
  overview
  alt-tab
  close
  new-window
  devtools
  context-menu
  file-dialogs
  tty
  run-command
  reboot
  usb-automount
  a11y
)

SELF="${KODERUP_KIOSK_BIN:-}"
if [[ -z "$SELF" ]]; then
  SELF="$(command -v koderup-kiosk 2>/dev/null || true)"
fi
if [[ -z "$SELF" ]]; then
  SELF="$0"
fi

usage() {
  cat <<'EOF'
Brug: koderup-kiosk <kommando> [valg]

Kommandoer:
  start     Start kiosk (standard: tilfældig sværhedsgrad + hints)
  stop      Stop kiosk og gendan skrivebordet
  status    Vis om kiosk kører, og hvilke escapes der er tilladt
  help      Vis denne hjælp

Valg til start:
  --scenario easy|medium|hard|random   Sværhedsgrad (standard: random)
  --random                             Samme som --scenario random
  --url URL                            Åbn anden side i stedet for demo
  --hints / --no-hints                 Vis/skjul how-to på demo-siden (standard: hints)
  --allow-NAVN / --no-allow-NAVN       Tillad eller bloker en escape

Escape-navne:
  overview alt-tab close new-window devtools context-menu
  file-dialogs tty run-command reboot usb-automount a11y

Eksempler:
  koderup-kiosk start
  koderup-kiosk start --scenario easy
  koderup-kiosk start --random --no-hints
  koderup-kiosk start --scenario hard --allow-tty
  koderup-kiosk stop
  sudo koderup-kiosk status
EOF
}

need_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    return 0
  fi
  local bin="$SELF"
  if [[ "$bin" != /* ]]; then
    bin="$(command -v "$bin" 2>/dev/null || true)"
  fi
  if [[ -n "$bin" ]]; then
    bin="$(readlink -f "$bin")"
  fi
  exec /run/wrappers/bin/sudo -n "${bin:-$SELF}" "$@"
}

ensure_state_dir() {
  mkdir -p "$STATE" "$STATE/dconf-backup" "$STATE/keyd" "$STATE/profile"
  chmod 755 "$STATE"
}

write_flag() {
  local name="$1" value="$2"
  printf '%s\n' "$value" >"$STATE/flag-$name"
}

read_flag() {
  local name="$1"
  local f="$STATE/flag-$name"
  if [[ -f "$f" ]]; then
    cat "$f"
  else
    echo "1"
  fi
}

flag_allowed() {
  local v
  v="$(read_flag "$1")"
  [[ "$v" == "1" || "$v" == "true" || "$v" == "allow" || "$v" == "yes" ]]
}

set_all_flags() {
  local value="$1"
  local e
  for e in "${ESCAPES[@]}"; do
    write_flag "$e" "$value"
  done
}

apply_scenario() {
  local scenario="$1"
  case "$scenario" in
    easy)
      set_all_flags 1
      ;;
    medium)
      set_all_flags 1
      write_flag overview 0
      write_flag alt-tab 0
      write_flag run-command 0
      write_flag a11y 0
      ;;
    hard)
      set_all_flags 0
      ;;
    random)
      randomize_flags
      ;;
    *)
      echo "Ukendt scenarie: $scenario" >&2
      exit 2
      ;;
  esac
  printf '%s\n' "$scenario" >"$STATE/scenario"
}

randomize_flags() {
  local n=${#ESCAPES[@]}
  local k
  # K ensartet fra 0..N
  k=$((RANDOM % (n + 1)))
  local -a shuffled=("${ESCAPES[@]}")
  local i j tmp
  for ((i = n - 1; i > 0; i--)); do
    j=$((RANDOM % (i + 1)))
    tmp="${shuffled[i]}"
    shuffled[i]="${shuffled[j]}"
    shuffled[j]="$tmp"
  done
  set_all_flags 0
  for ((i = 0; i < k; i++)); do
    write_flag "${shuffled[i]}" 1
  done
}

anon_uid() {
  id -u "$KIOSK_USER"
}

anon_runtime() {
  echo "/run/user/$(anon_uid)"
}

anon_env_ok() {
  local runtime
  runtime="$(anon_runtime)"
  [[ -S "$runtime/bus" ]]
}

userctl() {
  systemctl --user -M "${KIOSK_USER}@" "$@"
}

run_as_anon() {
  local runtime
  runtime="$(anon_runtime)"
  env \
    HOME="/home/$KIOSK_USER" \
    USER="$KIOSK_USER" \
    LOGNAME="$KIOSK_USER" \
    XDG_RUNTIME_DIR="$runtime" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus" \
    DISPLAY="${DISPLAY:-:0}" \
    WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
    runuser -u "$KIOSK_USER" -- "$@"
}

dconf_get() {
  run_as_anon dconf read "$1" 2>/dev/null || true
}

dconf_write() {
  run_as_anon dconf write "$1" "$2"
}

dconf_reset() {
  run_as_anon dconf reset "$1" 2>/dev/null || true
}

backup_dconf_key() {
  local key="$1"
  local safe
  safe="$(printf '%s' "$key" | tr '/' '_')"
  dconf_get "$key" >"$STATE/dconf-backup/$safe" || true
  printf '%s\n' "$key" >>"$STATE/dconf-backup/keys.list"
}

restore_dconf() {
  local list="$STATE/dconf-backup/keys.list"
  [[ -f "$list" ]] || return 0
  local key safe val
  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    safe="$(printf '%s' "$key" | tr '/' '_')"
    if [[ -f "$STATE/dconf-backup/$safe" ]]; then
      val="$(cat "$STATE/dconf-backup/$safe")"
      if [[ -n "$val" ]]; then
        dconf_write "$key" "$val" || true
      else
        dconf_reset "$key" || true
      fi
    fi
  done <"$list"
  rm -rf "$STATE/dconf-backup"
  mkdir -p "$STATE/dconf-backup"
}

apply_dconf_lockdown() {
  rm -rf "$STATE/dconf-backup"
  mkdir -p "$STATE/dconf-backup"
  : >"$STATE/dconf-backup/keys.list"

  local keys=(
    /org/gnome/mutter/overlay-key
    /org/gnome/desktop/interface/enable-hot-corners
    /org/gnome/desktop/wm/keybindings/switch-applications
    /org/gnome/desktop/wm/keybindings/switch-applications-backward
    /org/gnome/desktop/wm/keybindings/switch-windows
    /org/gnome/desktop/wm/keybindings/switch-windows-backward
    /org/gnome/desktop/wm/keybindings/close
    /org/gnome/desktop/wm/keybindings/panel-run-dialog
    /org/gnome/desktop/lockdown/disable-command-line
    /org/gnome/desktop/a11y/applications/screen-keyboard-enabled
    /org/gnome/desktop/a11y/applications/screen-reader-enabled
    /org/gnome/desktop/a11y/applications/screen-magnifier-enabled
    /org/gnome/desktop/a11y/keyboard/stickykeys-enable
    /org/gnome/desktop/a11y/keyboard/enable
    /org/gnome/desktop/media-handling/automount
    /org/gnome/desktop/media-handling/automount-open
  )
  local k
  for k in "${keys[@]}"; do
    backup_dconf_key "$k"
  done

  # Altid: hot corners fra under kiosk (undgår uheldig oversigt).
  dconf_write /org/gnome/desktop/interface/enable-hot-corners false

  if ! flag_allowed overview; then
    dconf_write /org/gnome/mutter/overlay-key "''"
  fi
  if ! flag_allowed alt-tab; then
    dconf_write /org/gnome/desktop/wm/keybindings/switch-applications '@as []'
    dconf_write /org/gnome/desktop/wm/keybindings/switch-applications-backward '@as []'
    dconf_write /org/gnome/desktop/wm/keybindings/switch-windows '@as []'
    dconf_write /org/gnome/desktop/wm/keybindings/switch-windows-backward '@as []'
  fi
  if ! flag_allowed close; then
    dconf_write /org/gnome/desktop/wm/keybindings/close '@as []'
  fi
  if ! flag_allowed run-command; then
    dconf_write /org/gnome/desktop/wm/keybindings/panel-run-dialog '@as []'
    dconf_write /org/gnome/desktop/lockdown/disable-command-line true
  fi
  if ! flag_allowed a11y; then
    dconf_write /org/gnome/desktop/a11y/applications/screen-keyboard-enabled false
    dconf_write /org/gnome/desktop/a11y/applications/screen-reader-enabled false
    dconf_write /org/gnome/desktop/a11y/applications/screen-magnifier-enabled false
    dconf_write /org/gnome/desktop/a11y/keyboard/stickykeys-enable false
    dconf_write /org/gnome/desktop/a11y/keyboard/enable false
  fi
  if ! flag_allowed usb-automount; then
    dconf_write /org/gnome/desktop/media-handling/automount false
    dconf_write /org/gnome/desktop/media-handling/automount-open false
  fi
}

write_keyd_config() {
  # keyd kræver leftcontrol (ikke "control"). Lag-typer: C, A, C-S, C-A.
  local conf="$STATE/keyd/default.conf"
  {
    echo '[ids]'
    echo '*'
    echo
    echo '[main]'
  } >"$conf"

  if ! flag_allowed overview; then
    {
      echo 'leftmeta = layer(meta_block)'
      echo 'rightmeta = layer(meta_block)'
    } >>"$conf"
  fi

  if ! flag_allowed devtools; then
    echo 'f12 = noop' >>"$conf"
  fi

  local need_control=0
  local need_control_shift=0
  local need_control_alt=0
  local need_alt=0

  if ! flag_allowed new-window || ! flag_allowed file-dialogs || ! flag_allowed close; then
    need_control=1
  fi
  if ! flag_allowed new-window || ! flag_allowed devtools; then
    need_control=1
    need_control_shift=1
  fi
  if ! flag_allowed tty; then
    need_control=1
    need_control_alt=1
  fi
  if ! flag_allowed close || ! flag_allowed run-command || ! flag_allowed alt-tab; then
    need_alt=1
  fi

  if [[ "$need_control" -eq 1 ]]; then
    {
      echo 'leftcontrol = layer(ctrl_block)'
      echo 'rightcontrol = layer(ctrl_block)'
    } >>"$conf"
  fi
  if [[ "$need_alt" -eq 1 ]]; then
    {
      echo 'leftalt = layer(alt_block)'
      echo 'rightalt = layer(alt_block)'
    } >>"$conf"
  fi

  if ! flag_allowed overview; then
    printf '\n[meta_block]\n' >>"$conf"
  fi

  if [[ "$need_control" -eq 1 ]]; then
    {
      echo
      echo '[ctrl_block:C]'
      if ! flag_allowed new-window; then
        echo 'n = noop'
        echo 't = noop'
      fi
      if ! flag_allowed close; then
        echo 'w = noop'
      fi
      if ! flag_allowed file-dialogs; then
        echo 'o = noop'
        echo 's = noop'
        echo 'p = noop'
      fi
      if [[ "$need_control_shift" -eq 1 ]]; then
        echo 'leftshift = layer(ctrl_shift_block)'
        echo 'rightshift = layer(ctrl_shift_block)'
      fi
      if [[ "$need_control_alt" -eq 1 ]]; then
        echo 'leftalt = layer(ctrl_alt_block)'
        echo 'rightalt = layer(ctrl_alt_block)'
      fi
    } >>"$conf"
  fi

  if [[ "$need_control_shift" -eq 1 ]]; then
    {
      echo
      echo '[ctrl_shift_block:C-S]'
      if ! flag_allowed new-window; then
        echo 'n = noop'
      fi
      if ! flag_allowed devtools; then
        echo 'i = noop'
        echo 'j = noop'
        echo 'c = noop'
      fi
    } >>"$conf"
  fi

  if [[ "$need_control_alt" -eq 1 ]]; then
    {
      echo
      echo '[ctrl_alt_block:C-A]'
      echo 'f1 = noop'
      echo 'f2 = noop'
      echo 'f3 = noop'
      echo 'f4 = noop'
      echo 'f5 = noop'
      echo 'f6 = noop'
      echo 'f7 = noop'
    } >>"$conf"
  fi

  if [[ "$need_alt" -eq 1 ]]; then
    {
      echo
      echo '[alt_block:A]'
      if ! flag_allowed alt-tab; then
        echo 'tab = noop'
      fi
      if ! flag_allowed close; then
        echo 'f4 = noop'
      fi
      if ! flag_allowed run-command; then
        echo 'f2 = noop'
      fi
    } >>"$conf"
  fi
}

keyd_needed() {
  local e
  for e in overview alt-tab close new-window devtools file-dialogs tty run-command; do
    if ! flag_allowed "$e"; then
      return 0
    fi
  done
  return 1
}

cmd_stop_units() {
  userctl stop koderup-kiosk-browser.service 2>/dev/null || true
  systemctl stop koderup-kiosk-browser.service 2>/dev/null || true
  systemctl stop koderup-kiosk-inhibit.service 2>/dev/null || true
  systemctl stop koderup-kiosk-keyd.service 2>/dev/null || true
  # Side-serveren stoppes kun ved fuld stop (ikke --from-api).
  if [[ "${FROM_API:-0}" != "1" ]]; then
    systemctl stop koderup-kiosk-page.service 2>/dev/null || true
  fi
}

cmd_start() {
  local scenario="random"
  local hints=1
  local url=""
  local -a overrides=()
  FROM_API=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scenario)
        scenario="${2:-}"
        shift 2
        ;;
      --random)
        scenario="random"
        shift
        ;;
      --url)
        url="${2:-}"
        shift 2
        ;;
      --hints)
        hints=1
        shift
        ;;
      --no-hints)
        hints=0
        shift
        ;;
      --from-api)
        FROM_API=1
        shift
        ;;
      --allow-*)
        overrides+=("allow:${1#--allow-}")
        shift
        ;;
      --no-allow-*)
        overrides+=("deny:${1#--no-allow-}")
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        echo "Ukendt valg: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done

  case "$scenario" in
    easy | medium | hard | random) ;;
    *)
      echo "Ukendt scenarie: $scenario" >&2
      exit 2
      ;;
  esac

  if ! anon_env_ok; then
    echo "Ingen grafisk session for $KIOSK_USER (mangler D-Bus i $(anon_runtime))." >&2
    echo "Log ind som $KIOSK_USER først (autologin)." >&2
    exit 1
  fi

  ensure_state_dir

  # Ved fuld start: stop gamle enheder først (behold page ved API).
  if [[ "$FROM_API" != "1" ]]; then
    cmd_stop_units
    # Gendan evt. gammel dconf før ny lockdown.
    if [[ -f "$STATE/dconf-backup/keys.list" ]]; then
      restore_dconf || true
    fi
  else
    userctl stop koderup-kiosk-browser.service 2>/dev/null || true
    systemctl stop koderup-kiosk-browser.service 2>/dev/null || true
    systemctl stop koderup-kiosk-inhibit.service 2>/dev/null || true
    systemctl stop koderup-kiosk-keyd.service 2>/dev/null || true
    if [[ -f "$STATE/dconf-backup/keys.list" ]]; then
      restore_dconf || true
    fi
  fi

  apply_scenario "$scenario"

  local ov name
  for ov in "${overrides[@]+"${overrides[@]}"}"; do
    name="${ov#*:}"
    local ok=0
    local e
    for e in "${ESCAPES[@]}"; do
      if [[ "$e" == "$name" ]]; then
        ok=1
        break
      fi
    done
    if [[ "$ok" -ne 1 ]]; then
      echo "Ukendt escape: $name" >&2
      exit 2
    fi
    if [[ "$ov" == allow:* ]]; then
      write_flag "$name" 1
    else
      write_flag "$name" 0
    fi
  done

  printf '%s\n' "$hints" >"$STATE/hints"

  if [[ -z "$url" ]]; then
    if [[ "$hints" -eq 1 ]]; then
      url="${DEMO_URL}?hints=1"
    else
      url="${DEMO_URL}?hints=0"
    fi
    printf '%s\n' "demo" >"$STATE/page-mode"
  else
    printf '%s\n' "external" >"$STATE/page-mode"
  fi
  printf '%s\n' "$url" >"$STATE/url"

  apply_dconf_lockdown

  if keyd_needed; then
    write_keyd_config
    systemctl start koderup-kiosk-keyd.service
  fi

  if ! flag_allowed reboot; then
    systemctl start koderup-kiosk-inhibit.service
  fi

  # Demo-side (localhost) — ikke ved --url
  if [[ "$(cat "$STATE/page-mode")" == "demo" && "$FROM_API" != "1" ]]; then
    systemctl start koderup-kiosk-page.service
    local i
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
      if python3 -c "import socket; s=socket.socket(); s.settimeout(0.2); s.connect(('127.0.0.1', ${PAGE_PORT})); s.close()" 2>/dev/null; then
        break
      fi
      sleep 0.15
    done
  fi

  # Browser-genstart-politik
  if flag_allowed close; then
    printf 'no\n' >"$STATE/browser-restart"
  else
    printf 'always\n' >"$STATE/browser-restart"
  fi

  # Extension hvis context-menu blokeret
  if flag_allowed context-menu; then
    printf '0\n' >"$STATE/load-extension"
  else
    printf '1\n' >"$STATE/load-extension"
  fi

  userctl start koderup-kiosk-browser.service
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if userctl is-active --quiet koderup-kiosk-browser.service; then
      break
    fi
    sleep 0.2
  done
  if ! userctl is-active --quiet koderup-kiosk-browser.service; then
    echo "Kiosk-browseren startede ikke." >&2
    userctl status koderup-kiosk-browser.service --no-pager >&2 || true
    exit 1
  fi

  echo "Kiosk startet (scenarie: $scenario)."
  if [[ "$scenario" == "random" ]]; then
    echo "Tilladte escapes:"
    local e
    for e in "${ESCAPES[@]}"; do
      if flag_allowed "$e"; then
        echo "  - $e"
      fi
    done
  fi
}

cmd_stop() {
  cmd_stop_units
  if anon_env_ok && [[ -f "$STATE/dconf-backup/keys.list" ]]; then
    restore_dconf || true
  fi
  # Ryd midlertidig profil/flag — behold mappen til næste start
  rm -f "$STATE"/flag-* "$STATE/scenario" "$STATE/hints" "$STATE/url" \
    "$STATE/page-mode" "$STATE/browser-restart" "$STATE/load-extension" 2>/dev/null || true
  rm -rf "$STATE/keyd" "$STATE/profile" 2>/dev/null || true
  mkdir -p "$STATE/keyd" "$STATE/profile"
  echo "Kiosk stoppet."
}

cmd_status() {
  if userctl is-active --quiet koderup-kiosk-browser.service 2>/dev/null; then
    echo "Status: kører"
  else
    echo "Status: stoppet"
  fi
  if [[ -f "$STATE/scenario" ]]; then
    echo "Scenarie: $(cat "$STATE/scenario")"
  fi
  if [[ -f "$STATE/hints" ]]; then
    if [[ "$(cat "$STATE/hints")" == "1" ]]; then
      echo "Hints: til"
    else
      echo "Hints: fra"
    fi
  fi
  if [[ -f "$STATE/url" ]]; then
    echo "URL: $(cat "$STATE/url")"
  fi
  echo "Escapes:"
  local e
  for e in "${ESCAPES[@]}"; do
    if [[ -f "$STATE/flag-$e" ]]; then
      if flag_allowed "$e"; then
        echo "  $e: tilladt"
      else
        echo "  $e: blokeret"
      fi
    fi
  done
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    start | stop | status)
      need_root "$cmd" "$@"
      case "$cmd" in
        start) cmd_start "$@" ;;
        stop) cmd_stop "$@" ;;
        status) cmd_status "$@" ;;
      esac
      ;;
    help | -h | --help | "")
      usage
      ;;
    *)
      echo "Ukendt kommando: $cmd" >&2
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
