# BBC micro:bit USB access for MakeCode / Python editors
# (https://makecode.microbit.org, https://python.microbit.org) via WebUSB.
# udev TAG+=uaccess must live in a rules file that sorts before
# 73-seat-late.rules — services.udev.extraRules writes 99-local.rules and
# is too late (https://github.com/NixOS/nixpkgs/issues/308681).
{ pkgs, ... }:

{
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "microbit-udev-rules";
      destination = "/etc/udev/rules.d/70-microbit.rules";
      text = ''
        # BBC micro:bit DAPLink (vendor 0d28 = 3368 decimal).
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0d28", TAG+="uaccess"
        SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0d28", TAG+="uaccess"
      '';
    })
  ];
}
