# Authoritative for koderup.dk only. The address is this host's Netbird IPv4,
# rewritten whenever wt0 changes. Not a recursive resolver.
{ pkgs, ... }:
{
  systemd.tmpfiles.rules = [
    "d /run/koderup-dns 0755 root root -"
  ];

  # Do not install 127.0.0.1 as the system resolver. This dnsmasq only
  # answers koderup.dk; public lookups must keep using the Wi-Fi DNS.
  # Port 5353: Netbird already binds the Netbird address on port 53.
  services.dnsmasq.enable = true;
  services.dnsmasq.resolveLocalQueries = false;
  services.dnsmasq.settings = {
    port = 5353;
    interface = "wt0";
    bind-interfaces = true;
    no-resolv = true;
    no-hosts = true;
    conf-dir = "/run/koderup-dns,*.conf";
  };

  systemd.services.dnsmasq = {
    after = [ "netbird.service" "koderup-dns-address.service" ];
    wants = [ "koderup-dns-address.service" ];
    serviceConfig.Restart = "on-failure";
    serviceConfig.RestartSec = "5s";
  };

  systemd.services.koderup-dns-address = {
    description = "Publish koderup.dk on this host's Netbird address";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "netbird.service" ];
    wants = [ "network-online.target" ];
    path = with pkgs; [
      iproute2
      coreutils
      gawk
      systemd
    ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      set -euo pipefail
      ip=$(ip -4 -o addr show dev wt0 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1 || true)
      if [ -z "$ip" ]; then
        echo "wt0 has no IPv4 address yet" >&2
        exit 0
      fi
      dir=/run/koderup-dns
      mkdir -p "$dir"
      new=$dir/koderup.conf.new
      cat > "$new" <<EOF
address=/koderup.dk/$ip
EOF
      if [ -f "$dir/koderup.conf" ] && cmp -s "$new" "$dir/koderup.conf"; then
        rm -f "$new"
        exit 0
      fi
      mv "$new" "$dir/koderup.conf"
      # Do not call systemctl here. dnsmasq waits for this unit, so a reload
      # or restart from inside it deadlocks the switch.
      pid=$(systemctl show -p MainPID --value dnsmasq || true)
      if [ -n "$pid" ] && [ "$pid" != 0 ]; then
        kill -HUP "$pid" || true
      fi
    '';
  };

  systemd.timers.koderup-dns-address = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15s";
      OnUnitActiveSec = "60s";
    };
  };
}
