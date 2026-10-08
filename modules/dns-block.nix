# DNS block list for managed laptops.
# The domains live in ./dns-blocklist.txt. Each domain and its www. host are
# sinkholed via /etc/hosts (IPv4 + IPv6).
# Note: /etc/hosts has no wildcards, so this only catches the apex + www.
# host, not arbitrary subdomains. YouTube is blocked via browser policy
# (see modules/firefox.nix / modules/chromium.nix), not here.
#
# /etc/hosts is a symlink to /var/lib/dns-block/hosts so the list can change
# without a NixOS rebuild. A timer re-downloads dns-blocklist.txt from main
# every 5 minutes on Thursdays 17:00-19:00 and regenerates the file.
# systemd-resolved consults /etc/hosts before its cache and notices changes
# within 2 seconds, so a refreshed list is live within one 5-minute cycle.
{ config, lib, pkgs, ... }:
let
  stateDir = "/var/lib/dns-block";
  builtList = ./dns-blocklist.txt;
  listUrl = "https://raw.githubusercontent.com/jensfriisnielsen/cpb-laptops/main/modules/dns-blocklist.txt";

  # What /etc/hosts would contain without the block list (localhost, hostname).
  baseHosts = pkgs.concatText "hosts-base" config.networking.hostFiles;

  apply = pkgs.writeShellApplication {
    name = "dns-block-apply";
    runtimeInputs = with pkgs; [ coreutils gnused gnugrep ];
    text = ''
      list=${stateDir}/blocklist.txt
      [ -f "$list" ] || list=${builtList}
      tmp=$(mktemp ${stateDir}/hosts.XXXXXX)
      trap 'rm -f "$tmp"' EXIT
      {
        cat ${baseHosts}
        echo
        echo "# Block list from $list (modules/dns-block.nix)"
        sed -e 's/#.*//' -e 's/[[:space:]]//g' "$list" \
          | tr '[:upper:]' '[:lower:]' \
          | { grep -E '^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$' || true; } \
          | sort -u \
          | while read -r d; do
              echo "0.0.0.0 $d www.$d"
              echo ":: $d www.$d"
            done
      } > "$tmp"
      chmod 0644 "$tmp"
      mv -f "$tmp" ${stateDir}/hosts
    '';
  };

  fetch = pkgs.writeShellApplication {
    name = "dns-block-fetch";
    runtimeInputs = with pkgs; [ coreutils curl gnugrep apply ];
    text = ''
      tmp=$(mktemp ${stateDir}/download.XXXXXX)
      trap 'rm -f "$tmp"' EXIT
      curl -fsSL --max-time 30 --retry 2 -o "$tmp" ${lib.escapeShellArg listUrl}
      # Refuse obviously broken downloads (error pages, truncated files).
      count=$(grep -cE '^[[:space:]]*[A-Za-z0-9.-]+\.[A-Za-z]{2,}[[:space:]]*$' "$tmp" || true)
      if [ "$count" -lt 10 ]; then
        echo "Downloaded block list has only $count domains; keeping current list." >&2
        exit 1
      fi
      chmod 0644 "$tmp"
      mv -f "$tmp" ${stateDir}/blocklist.txt
      dns-block-apply
      echo "DNS block list updated ($count domains)."
    '';
  };
in
{
  environment.etc.hosts.source = lib.mkForce "${stateDir}/hosts";

  # Runs on every boot and switch. A rebuild ships a list at least as new as
  # the last download, so it replaces the downloaded copy when it changes.
  system.activationScripts.dns-block = ''
    install -d -m 0755 ${stateDir}
    if ! ${pkgs.diffutils}/bin/cmp -s ${builtList} ${stateDir}/built.txt; then
      install -m 0644 ${builtList} ${stateDir}/blocklist.txt
      install -m 0644 ${builtList} ${stateDir}/built.txt
    fi
    ${apply}/bin/dns-block-apply || echo "dns-block: failed to write ${stateDir}/hosts" >&2
  '';

  systemd.services.dns-block-fetch = {
    description = "Refresh DNS block list from GitHub";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${fetch}/bin/dns-block-fetch";
    };
  };

  systemd.timers.dns-block-fetch = {
    description = "Refresh DNS block list every 5 minutes on Thursdays 17:00-19:00";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Thu *-*-* 17,18:00/5:00";
      RandomizedDelaySec = "60";
    };
  };

  environment.systemPackages = [ apply fetch ];
}
