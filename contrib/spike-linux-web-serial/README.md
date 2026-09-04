# Making LEGO SPIKE work with Chromium on Linux

LEGO’s classroom app at [spike.legoeducation.com](https://spike.legoeducation.com/) talks to SPIKE hubs over USB from the browser. Officially that means Chrome on Chromebooks, Windows, and macOS. On Linux the same page often fails in two ways:

1. The serial chooser shows the hub, but selecting it does nothing.
2. Connect works, but hub software update (hub OS / hub-styresystem) or program upload times out.

This directory is a small, distro-agnostic fix: one udev rules file, one Python helper, and a systemd unit. It is the same approach used on the [cpb-laptops](https://github.com/jensfriisnielsen/cpb-laptops) NixOS classroom fleet ([`modules/spike.nix`](../../modules/spike.nix)).

## How the browser talks to the hub

USB presents the hub as a virtual serial port (CDC ACM): `COM*` on Windows, `/dev/ttyACM*` on Linux. The web app uses the **Web Serial** API at 115200 baud. That API exists in Chromium, Google Chrome, and Brave. **Firefox has no Web Serial**, so it cannot connect.

The same serial link carries two different languages:

- **Everyday use** (connect, run Word Blocks / Python) is LEGO’s binary hub protocol. The app sends framed packets and waits for replies such as `ProgramFlowResponse`.
- **Hub software update** switches the port into **MicroPython raw REPL**. The JavaScript sends Ctrl-C and Ctrl-A, waits a few seconds for the banner `raw REPL; CTRL-B to exit`, then uploads files through that REPL. If the banner never arrives, the update fails with a timeout (Danish UI: *“Der opstod en fejl under opdatering af hub-styresystem”*).

## What DTR is, and why Linux is special

**DTR (Data Terminal Ready)** is an old modem control line that still exists on USB-serial stacks. Many STM32 CDC firmwares (including SPIKE Prime) treat DTR as “a host is actually here”: with DTR low they still accept USB writes, but they send nothing back. RTS is the matching “please send” line; this pack sets both.

On **Windows, macOS, and ChromeOS**, opening the serial device from Chromium asserts DTR. LEGO’s supported browsers therefore just work: connect and REPL both see replies.

On **Linux**, Chromium opens `/dev/ttyACM*`, applies Web Serial’s termios2 settings for baud/raw mode, and leaves DTR cleared. The chooser can succeed and the app can write Ctrl-A, but the hub stays silent, so the REPL wait times out.

Separately, Chromium’s sandbox **drops the `dialout` group**. Being in `dialout` helps `minicom` and friends; it does **not** let sandboxed Web Serial open the tty. The seat needs `TAG+=uaccess` on the **tty** node, not only on the USB device. Without that, the chooser can list the hub and selecting it does nothing.

## What this pack installs

| File | Role |
| --- | --- |
| `udev/70-lego-spike.rules` | `uaccess` on LEGO USB / hidraw / **tty** (vendor `0694`), ignore ModemManager |
| `spike-serial-dtr.py` | While Chromium/Chrome/Brave holds a LEGO tty, raise DTR/RTS on that fd only |
| `systemd/spike-serial-dtr.service` | Keep the helper running |

The udev filename must sort **before** systemd’s `73-seat-late.rules` (hence `70-…`). A `99-local.rules` file is too late for seat ACLs.

The helper **must not** keep its own open of `/dev/ttyACM*`. Doing that makes the kernel keep reading while the app is gone: stale hub packets fill the buffer, reconnect gets `ProgramFlowResponse` Nack, and Chromium logs `FILE_ERROR_IN_USE`.

## Install (systemd)

Requirements: root, `python3`, `udevadm`, `systemctl` (Ubuntu, Fedora, Arch, Debian, most desktops).

```sh
cd contrib/spike-linux-web-serial
sudo ./install.sh
```

Then fully quit the browser, replug the hub, open https://spike.legoeducation.com in Chromium/Chrome/Brave, and connect over USB.

Remove with:

```sh
sudo ./uninstall.sh
```

### Non-systemd hosts

Copy `udev/70-lego-spike.rules` into `/etc/udev/rules.d/`, reload udev, and run `spike-serial-dtr.py` under whatever supervisor you use. There is no OpenRC unit in this pack.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Hub never in chooser | Chromium/Chrome/Brave only; data cable; replug; `lsusb` shows `0694:` |
| Chooser shows hub, select does nothing | Rules installed as `70-…`? `udevadm info -n /dev/ttyACM0` includes `uaccess`? Fully quit browser after install |
| Connect OK, hub OS update / upload fails | `systemctl status spike-serial-dtr`; helper running? After connect, DTR should go high on the browser’s fd |
| Reconnect fails / `FILE_ERROR_IN_USE` | Nothing else should hold `/dev/ttyACM*` open; quit browser; ensure you are not using an older helper that opens the tty itself |
| Snap/Flatpak Chromium | Sandbox may still block the device even with udev; prefer distro Chromium or Chrome `.deb`/`.rpm` |
| ModemManager grabs the port | Rules set `ID_MM_DEVICE_IGNORE`; stop MM temporarily to test |

Do **not** add Atmel `03eb:6124` (NXT DFU); it collides with some Arduino boards.

## License / provenance

Same project as the classroom NixOS config. Licensed under the [GNU General Public License v3.0 or later](LICENSE). Feedback and improvements welcome upstream.
