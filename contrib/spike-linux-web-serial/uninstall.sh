#!/bin/sh
# Remove LEGO SPIKE Web Serial workarounds installed by install.sh.
set -eu

PREFIX=/usr/local/lib/spike-linux-web-serial
UDEV_DST=/etc/udev/rules.d/70-lego-spike.rules
UNIT_DST=/etc/systemd/system/spike-serial-dtr.service

if [ "$(id -u)" -ne 0 ]; then
  echo "error: run as root (e.g. sudo $0)" >&2
  exit 1
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl disable --now spike-serial-dtr.service 2>/dev/null || true
fi

rm -f "$UDEV_DST" "$UNIT_DST"
rm -rf "$PREFIX"

if command -v udevadm >/dev/null 2>&1; then
  udevadm control --reload-rules
  udevadm trigger --subsystem-match=tty --subsystem-match=usb || true
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload
fi

echo "Removed LEGO SPIKE Linux Web Serial fix."
echo "Fully quit the browser and replug the hub if you still have it connected."
