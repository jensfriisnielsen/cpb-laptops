# Fleet default WiFi: open classroom SSID.
{ ... }:

{
  networking.networkmanager.ensureProfiles.profiles."BAL-Internet" = {
    connection = {
      id = "BAL-Internet";
      type = "wifi";
      autoconnect = true;
      autoconnect-priority = 100;
    };
    wifi = {
      ssid = "BAL-Internet";
      mode = "infrastructure";
    };
    wifi-security.key-mgmt = "none";
    ipv4.method = "auto";
    ipv6.method = "auto";
  };
}
