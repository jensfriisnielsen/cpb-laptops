# LEGO Education SPIKE hub access for the web app
# (https://spike.legoeducation.com) via USB Web Serial / WebUSB and
# best-effort Chromium Web Bluetooth.
# udev TAG+=uaccess must live in a rules file that sorts before
# 73-seat-late.rules — services.udev.extraRules writes 99-local.rules and
# is too late (https://github.com/NixOS/nixpkgs/issues/308681).
{ pkgs, ... }:

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
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0694", TAG+="uaccess"
        SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0694", TAG+="uaccess"
      '';
    })
  ];
}
