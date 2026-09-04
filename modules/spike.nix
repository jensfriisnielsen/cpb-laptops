# LEGO Education SPIKE for the classroom web app
# (https://spike.legoeducation.com) over USB (Web Serial / WebUSB) and
# best-effort Chromium Web Bluetooth.
#
# What laptop users should do: Chromium or Brave (not Firefox), USB cable,
# connect in the app, then download programs or update hub software.
# Full classroom notes: README.md “LEGO SPIKE”.
#
# Two Linux problems this module fixes:
#
# 1) Chooser shows the hub but selecting it does nothing.
#    Chromium's sandbox drops the dialout group, so Web Serial cannot open
#    /dev/ttyACM* unless udev tags that tty with seat uaccess (USB-only
#    uaccess is not enough). TAG+=uaccess must live in a rules file that
#    sorts before 73-seat-late.rules — services.udev.extraRules writes
#    99-local.rules and is too late (https://github.com/NixOS/nixpkgs/issues/308681).
#
# 2) Connect works, but hub OS update / program upload fails
#    (Danish: “Der opstod en fejl under opdatering af hub-styresystem”).
#    The app speaks MicroPython raw REPL over the same USB serial. Chromium
#    on Linux leaves DTR low after it configures the port; the hub then
#    accepts writes but does not reply, so the app times out waiting for
#    "raw REPL; CTRL-B to exit".
#
#    Do not keep our own open of the tty: cdc_acm keeps reading while the
#    browser is gone, stale hub packets fill the kernel buffer, and the
#    next connect gets ProgramFlowResponse Nack. Raise DTR only on a
#    duplicate of Chromium/Brave's existing fd.
{ pkgs, ... }:

let
  # See module header: DTR/RTS on the browser's SPIKE tty fd only.
  spikeSerialDtr = pkgs.writeText "spike-serial-dtr.py" ''
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
                comm = open("/proc/%s/comm" % pid).read().strip()
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
  '';
in
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true;
  };

  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "lego-spike-udev-rules";
      destination = "/etc/udev/rules.d/70-lego-spike.rules";
      text = ''
        # LEGO Education SPIKE / MINDSTORMS hubs (vendor 0694 = 1684 decimal).
        # Vendor-wide so Prime, Essential, Inventor, and DFU modes all work.
        # Do not add Atmel 03eb:6124 (NXT DFU; collides with some Arduino boards).
        # Chromium's sandbox drops the dialout group, so Web Serial needs
        # seat uaccess on the tty node (not only the USB device).
        SUBSYSTEM=="usb", ATTR{idVendor}=="0694", TAG+="uaccess"
        SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0694", TAG+="uaccess"
        SUBSYSTEM=="tty", ATTRS{idVendor}=="0694", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"
      '';
    })
  ];

  systemd.services.spike-serial-dtr = {
    description = "Keep LEGO SPIKE USB serial ready so the web app can update the hub";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udevd.service" ];
    path = [ pkgs.python3 pkgs.udev ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 2;
      ExecStart = "${pkgs.python3}/bin/python3 ${spikeSerialDtr}";
    };
  };
}
