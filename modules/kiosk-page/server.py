#!/usr/bin/env python3
"""Localhost-only demo page + tiny API for koderup-kiosk."""
from __future__ import annotations

import json
import os
import subprocess
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

STATE = Path(os.environ.get("KODERUP_KIOSK_STATE", "/run/koderup-kiosk"))
PAGE_ROOT = Path(os.environ["KODERUP_KIOSK_PAGE"])
KIOSK_BIN = os.environ.get("KODERUP_KIOSK_BIN", "koderup-kiosk")
HOST = os.environ.get("KODERUP_KIOSK_HOST", "127.0.0.1")
PORT = int(os.environ.get("KODERUP_KIOSK_PORT", "4173"))

ESCAPE_IDS = [
    "overview",
    "alt-tab",
    "close",
    "new-window",
    "devtools",
    "context-menu",
    "file-dialogs",
    "tty",
    "run-command",
    "reboot",
    "usb-automount",
    "a11y",
]


def read_text(name: str, default: str = "") -> str:
    path = STATE / name
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return default


def read_status() -> dict:
    scenario = read_text("scenario", "random")
    hints_raw = read_text("hints", "1")
    hints = hints_raw not in ("0", "false", "no")
    flags: dict[str, bool] = {}
    for esc in ESCAPE_IDS:
        val = read_text(f"flag-{esc}", "1")
        flags[esc] = val in ("1", "true", "yes", "allow")
    return {
        "scenario": scenario,
        "hints": hints,
        "flags": flags,
        "url": read_text("url", f"http://{HOST}:{PORT}/"),
    }


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(PAGE_ROOT), **kwargs)

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/api/status":
            body = json.dumps(read_status()).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path != "/api/mode":
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            data = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            self.send_error(400, "Ugyldig JSON")
            return
        scenario = str(data.get("scenario", "")).strip()
        if scenario not in ("easy", "medium", "hard", "random"):
            self.send_error(400, "Ukendt scenarie")
            return

        hints = read_text("hints", "1")
        cmd = [KIOSK_BIN, "start", "--scenario", scenario, "--from-api"]
        if hints in ("0", "false", "no"):
            cmd.append("--no-hints")
        else:
            cmd.append("--hints")

        try:
            subprocess.run(cmd, check=True, timeout=120)
        except subprocess.CalledProcessError as exc:
            msg = f"koderup-kiosk fejlede ({exc.returncode})".encode("utf-8")
            self.send_response(500)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)
            return
        except Exception as exc:  # noqa: BLE001
            msg = str(exc).encode("utf-8")
            self.send_response(500)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)
            return

        body = b'{"ok":true}'
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> int:
    if not PAGE_ROOT.is_dir():
        print(f"PAGE_ROOT mangler: {PAGE_ROOT}", file=sys.stderr)
        return 1
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"koderup-kiosk-page on http://{HOST}:{PORT}/", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
