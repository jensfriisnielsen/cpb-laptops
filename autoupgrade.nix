{ pkgs, ... }:
let
  koderupUpgrade = pkgs.writeShellApplication {
    name = "koderup-upgrade";
    runtimeInputs = with pkgs; [ systemd ];
    text = ''
      set -euo pipefail
      echo "Starter nixos-upgrade.service ..."
      status=0
      systemctl start nixos-upgrade.service || status=$?
      journalctl -u nixos-upgrade.service --no-pager
      if [ "$status" -ne 0 ]; then
        echo "Opgradering fejlede." >&2
        exit "$status"
      fi
      echo "Opgradering fuldført."
    '';
  };

  koderupUpgradePolicy = pkgs.writeTextDir "share/polkit-1/actions/com.koderup.upgrade.policy" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE policyconfig PUBLIC
      "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
      "http://www.freedesktop.org/standards/PolicyKit/1.0/policyconfig.dtd">
    <policyconfig>
      <action id="com.koderup.upgrade">
        <description>Opdater NixOS-systemet</description>
        <message>Adgangskode påkrævet for at opdatere systemet</message>
        <defaults>
          <allow_any>no</allow_any>
          <allow_inactive>no</allow_inactive>
          <allow_active>auth_admin</allow_active>
        </defaults>
        <annotate key="org.freedesktop.policykit.exec.path">${koderupUpgrade}/bin/koderup-upgrade</annotate>
        <annotate key="org.freedesktop.policykit.exec.allow_gui_agent">true</annotate>
      </action>
    </policyconfig>
  '';

  koderupUpgradeGui = pkgs.writeShellApplication {
    name = "koderup-upgrade-gui";
    runtimeInputs = with pkgs; [
      koderupUpgrade
      polkit
    ];
    text = ''
      pkexec --disable-internal-agent koderup-upgrade || true
      echo
      read -r -p "Tryk Enter for at lukke..." _
    '';
  };

  koderupUpgradeDesktop = pkgs.makeDesktopItem {
    name = "koderup-upgrade";
    desktopName = "Opdater system";
    comment = "Hent og installer den nyeste systemopdatering";
    exec = "${pkgs.gnome-console}/bin/kgx -- koderup-upgrade-gui";
    icon = "software-update-available";
    categories = [ "System" ];
  };
in
{
  # Pull the flake from GitHub and switch. Hostname must match nixosConfigurations
  # (koderup1 … koderup40). Randomized delay spreads load across the fleet.
  system.autoUpgrade = {
    enable = true;
    flake = "github:jensfriisnielsen/cpb-laptops";
    flags = [ "--refresh" ];
    dates = "17:30";
    randomizedDelaySec = "45min";
    persistent = true;
    allowReboot = false;
    #rebootWindow = {
    #  lower = "02:00";
    #  upper = "06:00";
    #};
  };

  environment.systemPackages = [
    koderupUpgrade
    koderupUpgradeGui
    koderupUpgradePolicy
    koderupUpgradeDesktop
  ];
}
