# Netbird is the only path to services on this host. Do not filter it.
# Wi-Fi and Ethernet keep the fleet firewall.
{
  networking.firewall.trustedInterfaces = [ "wt0" ];
}
