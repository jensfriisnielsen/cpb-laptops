#!/usr/bin/env bash
# Share this laptop's WiFi (default route) over Ethernet to a NixOS installer.
#
# Admin-laptop only. Creates a dedicated NetworkManager profile named
# `koderup-share` and does not modify any other connection. `down` deletes that
# profile, removes the firewall chain this script added, and restores the
# ethernet profile that was active before `up`.
set -euo pipefail

CON_NAME=koderup-share
CHAIN=KODERUP-SHARE
SHARE_ADDR=10.43.0.1/24
STATE_FILE=${KODERUP_SHARE_STATE:-${TMPDIR:-/tmp}/koderup-share.state}

usage() {
  cat <<EOF
Usage: share-eth up|down|status

  up      Create NetworkManager profile ${CON_NAME} (shared IPv4/DHCP+NAT),
          activate it on the ethernet NIC, and open the NixOS firewall for it.
  down    Delete ${CON_NAME}, remove firewall rules, restore the previous
          ethernet connection. Safe to run when already down.
  status  Show profile, address, leases, and leftover state.

Environment:
  ETH                   Ethernet interface (default: auto-detect)
  KODERUP_SHARE_STATE   State file (default: ${STATE_FILE})

The installer laptop gets an address in 10.43.0.0/24 (typically 10.43.0.10; gateway ${SHARE_ADDR%%/*}).
EOF
}

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

fw() {
  run_root iptables "$@"
}

fw6() {
  if ! command -v ip6tables >/dev/null 2>&1; then
    return 0
  fi
  run_root ip6tables "$@"
}

need_nmcli() {
  if ! command -v nmcli >/dev/null 2>&1; then
    echo "nmcli not found; this script needs NetworkManager on the administrator laptop." >&2
    exit 1
  fi
}

conn_exists() {
  nmcli -g NAME connection show | grep -Fxq "$CON_NAME"
}

conn_is_active() {
  nmcli -g NAME connection show --active | grep -Fxq "$CON_NAME"
}

active_connection_on() {
  local iface=$1
  local con
  con=$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null || true)
  if [ -z "$con" ] || [ "$con" = "--" ]; then
    return 1
  fi
  printf '%s\n' "$con"
}

uuid_of() {
  nmcli -g connection.uuid connection show "$1"
}

state_get() {
  local key=$1
  [ -f "$STATE_FILE" ] || return 0
  awk -F= -v k="$key" '$1 == k { print $2 }' "$STATE_FILE"
}

detect_eth() {
  if [ -n "${ETH:-}" ]; then
    printf '%s\n' "$ETH"
    return
  fi

  local device type state
  local connected="" disconnected=""
  while IFS=: read -r device type state; do
    [ "$type" = ethernet ] || continue
    case "$device" in
      docker*|virbr*|br-*|veth*|tailscale*|zt*) continue ;;
    esac
    case "$state" in
      connected) connected=$device ;;
      disconnected|connecting*) disconnected=$disconnected${disconnected:+$'\n'}$device ;;
    esac
  done < <(nmcli -t -f DEVICE,TYPE,STATE device status)

  if [ -n "$connected" ]; then
    printf '%s\n' "$connected"
    return
  fi
  if [ -n "$disconnected" ]; then
    printf '%s\n' "$disconnected" | head -n1
    return
  fi

  echo "No ethernet device found. Plug in a cable or set ETH=<interface>." >&2
  exit 1
}

save_prev() {
  local iface=$1
  if [ -f "$STATE_FILE" ]; then
    return
  fi

  local con uuid=""
  if con=$(active_connection_on "$iface"); then
    if [ "$con" != "$CON_NAME" ]; then
      uuid=$(uuid_of "$con")
    fi
  fi
  umask 077
  cat >"$STATE_FILE" <<EOF
IFACE=${iface}
PREV_UUID=${uuid}
EOF
}

fw_ensure_chain() {
  local cmd=$1
  local iface=$2
  if $cmd -L "$CHAIN" -n >/dev/null 2>&1; then
    $cmd -F "$CHAIN"
  else
    $cmd -N "$CHAIN"
  fi
  $cmd -A "$CHAIN" -i "$iface" -j ACCEPT
  $cmd -A "$CHAIN" -o "$iface" -j ACCEPT
  if ! $cmd -C INPUT -j "$CHAIN" >/dev/null 2>&1; then
    $cmd -I INPUT 1 -j "$CHAIN"
  fi
  if ! $cmd -C FORWARD -j "$CHAIN" >/dev/null 2>&1; then
    $cmd -I FORWARD 1 -j "$CHAIN"
  fi
}

fw_up() {
  local iface=$1
  run_root true
  fw_ensure_chain fw "$iface"
  if command -v ip6tables >/dev/null 2>&1; then
    fw_ensure_chain fw6 "$iface"
  fi
}

fw_remove_jumps() {
  local cmd=$1
  local hook
  for hook in INPUT FORWARD; do
    while $cmd -C "$hook" -j "$CHAIN" >/dev/null 2>&1; do
      $cmd -D "$hook" -j "$CHAIN"
    done
  done
  $cmd -F "$CHAIN" >/dev/null 2>&1 || true
  $cmd -X "$CHAIN" >/dev/null 2>&1 || true
}

fw_down() {
  run_root true
  fw_remove_jumps fw
  if command -v ip6tables >/dev/null 2>&1; then
    fw_remove_jumps fw6
  fi
}

ensure_profile() {
  local iface=$1
  if conn_exists; then
    nmcli connection modify "$CON_NAME" \
      connection.interface-name "$iface" \
      connection.autoconnect yes \
      connection.autoconnect-priority 100 \
      ipv4.method shared \
      ipv4.addresses "$SHARE_ADDR" \
      ipv4.never-default yes \
      ipv6.method disabled \
      ipv6.addr-gen-mode default
  else
    nmcli connection add type ethernet ifname "$iface" con-name "$CON_NAME" \
      connection.autoconnect yes \
      connection.autoconnect-priority 100 \
      ipv4.method shared \
      ipv4.addresses "$SHARE_ADDR" \
      ipv4.never-default yes \
      ipv6.method disabled \
      ipv6.addr-gen-mode default
  fi
}

cmd_up() {
  need_nmcli
  local iface
  iface=$(detect_eth)

  save_prev "$iface"
  ensure_profile "$iface"
  fw_up "$iface"
  nmcli connection up "$CON_NAME"

  echo "Shared ${iface} as ${CON_NAME} (${SHARE_ADDR})."
  echo "Installer laptops get DHCP in 10.43.0.0/24 (gateway ${SHARE_ADDR%%/*})."
  echo "Leases: /var/lib/NetworkManager/dnsmasq-${iface}.leases"
}

cmd_down() {
  need_nmcli
  local iface="" prev_uuid="" had_profile=0 had_state=0

  if conn_exists; then
    had_profile=1
    iface=$(nmcli -g connection.interface-name connection show "$CON_NAME")
  fi
  if [ -f "$STATE_FILE" ]; then
    had_state=1
    iface=${iface:-$(state_get IFACE)}
    prev_uuid=$(state_get PREV_UUID)
  fi

  fw_down

  if [ "$had_profile" -eq 0 ] && [ "$had_state" -eq 0 ]; then
    echo "${CON_NAME} already removed."
    return
  fi

  if conn_exists; then
    nmcli connection delete "$CON_NAME" >/dev/null
  fi

  if [ -n "$prev_uuid" ] && nmcli connection show "$prev_uuid" >/dev/null 2>&1; then
    nmcli connection up "$prev_uuid" >/dev/null
    echo "Restored previous ethernet profile (${prev_uuid}) on ${iface}."
  elif [ -n "$iface" ]; then
    # No prior profile: keep the NIC from autoconnecting a different profile.
    nmcli device disconnect "$iface" >/dev/null 2>&1 || true
    echo "Removed ${CON_NAME}; ${iface} left disconnected."
  else
    echo "Removed ${CON_NAME}."
  fi

  rm -f "$STATE_FILE"
}

cmd_status() {
  need_nmcli
  local iface=${ETH:-}

  if [ -z "$iface" ] && conn_exists; then
    iface=$(nmcli -g connection.interface-name connection show "$CON_NAME")
  fi
  if [ -z "$iface" ]; then
    iface=$(state_get IFACE)
  fi

  echo "Profile: ${CON_NAME}"
  if conn_exists; then
    echo "  exists: yes"
    echo "  uuid: $(uuid_of "$CON_NAME")"
    echo "  interface: $(nmcli -g connection.interface-name connection show "$CON_NAME")"
    echo "  ipv4.method: $(nmcli -g ipv4.method connection show "$CON_NAME")"
    echo "  ipv4.addresses: $(nmcli -g ipv4.addresses connection show "$CON_NAME")"
    if conn_is_active; then
      echo "  active: yes"
    else
      echo "  active: no"
    fi
  else
    echo "  exists: no"
  fi

  if [ -n "$iface" ]; then
    echo "Device: ${iface}"
    nmcli -g GENERAL.STATE,GENERAL.CONNECTION,IP4.ADDRESS device show "$iface" 2>/dev/null | sed 's/^/  /' || true
    local leases=/var/lib/NetworkManager/dnsmasq-${iface}.leases
    echo "Leases file: ${leases}"
    if [ -r "$leases" ]; then
      sed 's/^/  /' "$leases"
    fi
  fi

  echo "State file: ${STATE_FILE}"
  if [ -f "$STATE_FILE" ]; then
    sed 's/^/  /' "$STATE_FILE"
  else
    echo "  (absent)"
  fi

  echo "Firewall chain ${CHAIN} (iptables):"
  if iptables -L "$CHAIN" -n >/dev/null 2>&1; then
    iptables -L "$CHAIN" -n | sed 's/^/  /'
  else
    echo "  (absent or unreadable without root)"
  fi
}

case "${1:-}" in
  up | start | setup) cmd_up ;;
  down | stop | remove | teardown) cmd_down ;;
  status) cmd_status ;;
  -h | --help | help | "")
    usage
    [ "${1:-}" = "" ] && exit 1
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
