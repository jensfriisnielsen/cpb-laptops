#!/usr/bin/env python3
"""Assert DTR/RTS on LEGO SPIKE USB serial while Chromium/Brave holds the port.

Linux Chromium Web Serial leaves DTR low after termios2 configure. SPIKE Prime
STM32 CDC then accepts writes but does not transmit, so hub OS updates time out
waiting for MicroPython raw REPL.

This helper finds Chromium/Chrome/Brave's existing fd on LEGO ttyACM/ttyUSB
nodes and raises DTR/RTS. It must not keep its own open of the tty: that makes
cdc_acm keep reading while the app is gone (stale packets, reconnect Nack,
FILE_ERROR_IN_USE).
"""
import array
import fcntl
import glob
import os
import subprocess
import time

TIOCMGET, TIOCMSET = 0x5415, 0x5418
TIOCM_DTR, TIOCM_RTS = 0x002, 0x004
BROWSERS = {"chromium", "brave", "chrome", "brave-browser"}


def is_lego(node):
    try:
        props = subprocess.check_output(
            ["udevadm", "info", "-q", "property", "-n", node],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        return False
    return "ID_VENDOR_ID=0694" in props


def openers(node):
    out = []
    try:
        want = os.path.realpath(node)
    except OSError:
        return out
    for fdpath in glob.glob("/proc/[0-9]*/fd/[0-9]*"):
        try:
            target = os.readlink(fdpath)
        except OSError:
            continue
        if target != node and os.path.realpath(target) != want:
            continue
        pid = fdpath.split("/")[2]
        if pid == str(os.getpid()):
            continue
        try:
            with open("/proc/%s/comm" % pid) as f:
                comm = f.read().strip()
        except OSError:
            comm = "?"
        out.append((pid, comm, fdpath))
    return out


def assert_dtr(fd):
    buf = array.array("I", [0])
    fcntl.ioctl(fd, TIOCMGET, buf, True)
    want = buf[0] | TIOCM_DTR | TIOCM_RTS
    if buf[0] != want:
        fcntl.ioctl(fd, TIOCMSET, array.array("I", [want]))


def main():
    while True:
        for node in glob.glob("/dev/ttyACM*") + glob.glob("/dev/ttyUSB*"):
            if not is_lego(node):
                continue
            for pid, comm, fdpath in openers(node):
                if comm not in BROWSERS:
                    continue
                try:
                    fd = os.open(fdpath, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
                except OSError:
                    continue
                try:
                    assert_dtr(fd)
                except OSError:
                    pass
                finally:
                    os.close(fd)
        time.sleep(0.5)


if __name__ == "__main__":
    main()
