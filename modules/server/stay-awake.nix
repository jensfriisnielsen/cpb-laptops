# Keep the GNOME session, the machine, and Wi-Fi up. This host is a server.
{ lib, ... }:
{
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
    IdleAction = "ignore";
  };

  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  networking.networkmanager.wifi.powersave = false;

  programs.dconf.profiles.user.databases = [
    {
      settings."org/gnome/settings-daemon/plugins/power" = {
        sleep-inactive-ac-type = "nothing";
        sleep-inactive-battery-type = "nothing";
        sleep-inactive-ac-timeout = lib.gvariant.mkInt32 0;
        sleep-inactive-battery-timeout = lib.gvariant.mkInt32 0;
      };
      settings."org/gnome/desktop/session" = {
        idle-delay = lib.gvariant.mkUint32 0;
      };
    }
  ];
}
