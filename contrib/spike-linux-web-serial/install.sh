#!/bin/sh
# Install LEGO SPIKE Web Serial workarounds for systemd Linux.
# Requires: root, python3, udevadm, systemctl
set -eu

PREFIX=/usr/local/lib/spike-linux-web-serial
UDEV_DST=/etc/udev/rules.d/70-lego-spike.rules
UNIT_DST=/etc/systemd/system/spike-serial-dtr.service

if [ "$(id -u)" -ne 0 ]; then
  echo "error: run as root (e.g. sudo $0)" >&2
  exit 1
fi

ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing required command: $1" >&2
    exit 1
  fi
}

need python3
need udevadm
need systemctl

install -d -m 0755 "$PREFIX"
install -m 0755 "$ROOT/spike-serial-dtr.py" "$PREFIX/spike-serial-dtr.py"
# Optional: ship the article next to the helper for the unit Documentation= line.
if [ -f "$ROOT/README.md" ]; then
  install -m 0644 "$ROOT/README.md" "$PREFIX/README.md"
fi
install -m 0644 "$ROOT/udev/70-lego-spike.rules" "$UDEV_DST"
install -m 0644 "$ROOT/systemd/spike-serial-dtr.service" "$UNIT_DST"

udevadm control --reload-rules
udevadm trigger --subsystem-match=tty --subsystem-match=usb || true

systemctl daemon-reload
systemctl enable --now spike-serial-dtr.service

cat <<'EOF'

Installed LEGO SPIKE Linux Web Serial fix.

  udev:    /etc/udev/rules.d/70-lego-spike.rules
  helper:  /usr/local/lib/spike-linux-web-serial/spike-serial-dtr.py
  service: spike-serial-dtr.service (enabled)

Use Chromium, Google Chrome, or Brave — not Firefox.
Use a USB data cable (not charge-only).

After install:
  1. Fully quit the browser (all windows), then open it again.
  2. Unplug and replug the hub if it was already connected.
  3. Open https://spike.legoeducation.com and connect over USB.

Membership in the dialout group helps native tools, but sandboxed Chromium
still needs the udev uaccess rules above.

Uninstall: sudo ./uninstall.sh
EOF
