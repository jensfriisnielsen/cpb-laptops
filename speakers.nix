{ lib, pkgs, ... }:

let
  muteInternalSpeakers = pkgs.writeShellApplication {
    name = "mute-internal-speakers";
    runtimeInputs = [ pkgs.alsa-utils ];
    text = ''
      mute_if_present() {
        local card="$1"
        local control="$2"
        amixer -q -c "$card" sset "$control" off || true
      }

      shopt -s nullglob
      for card_dir in /proc/asound/card[0-9]*; do
        [[ -d "$card_dir" ]] || continue
        card="''${card_dir##*/card}"
        # USB headsets often expose a Speaker control; leave them alone.
        if [[ -e "$card_dir/usbid" ]]; then
          continue
        fi
        mute_if_present "$card" "Speaker"
        mute_if_present "$card" "Bass Speaker"
      done
    '';
  };
in
{
  systemd.services.disable-internal-speakers = {
    description = "Mute built-in laptop speakers; leave headphones and other outputs";
    after = [ "sound.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe muteInternalSpeakers;
    };
  };

  systemd.timers.disable-internal-speakers = {
    description = "Re-mute built-in laptop speakers";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15s";
      OnUnitActiveSec = "15s";
      AccuracySec = "5s";
      Unit = "disable-internal-speakers.service";
    };
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="sound", KERNEL=="card*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="disable-internal-speakers.service"
  '';
}
