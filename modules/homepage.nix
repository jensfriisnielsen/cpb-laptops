# gethomepage.dev dashboard on every laptop (http://localhost:3000).
#
# Runs from the pinned nixpkgs homepage-dashboard package as a plain systemd
# service — no containers on laptops, no unpinned :latest image pulls.
#
# Notes from inspecting the homepage-dashboard package at the locked nixpkgs rev:
# - The wrapper bin/homepage runs node share/homepage/server.js (Next.js
#   standalone). That server reads PORT and HOSTNAME; HOSTNAME is its *bind
#   address*. The nixpkgs package ships the upstream install-script placeholder
#   '[IP_ADDRESS]' unreplaced (upstream sed-replaces it with the machine IP),
#   which is not a valid hostname — bind fails with ENOTFOUND. Override it to
#   pin the server to the loopback.
# - Config dir is $HOMEPAGE_CONFIG_DIR (default: <cwd>/config, read-only store
#   path). gethomepage writes a .cache there, so copy the generated config to a
#   writable dir before start.
# - Host validation defaults already allow "localhost:3000", so do NOT set
#   HOMEPAGE_ALLOWED_HOSTS (it would only add non-matching entries).
{ pkgs, ... }:

let
  settingsYaml = pkgs.writeText "homepage-settings.yaml" ''
    title: Koderup
  '';

  bookmarksYaml = pkgs.writeText "homepage-bookmarks.yaml" ''
    - Koderup:
        - Laptop-manual:
            - href: http://localhost:8888
              description: Manual til din laptop
        - koderup.dk:
            - href: https://koderup.dk
              description: Koderups hjemmeside
  '';

  homepageConfig = pkgs.runCommand "koderup-homepage-config" { } ''
    mkdir -p "$out"
    cp ${settingsYaml} "$out/settings.yaml"
    cp ${bookmarksYaml} "$out/bookmarks.yaml"
  '';
in
{
  systemd.services.koderup-homepage = {
    description = "gethomepage.dev dashboard (http://localhost:3000)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "local-fs.target"
      "koderup-manual.service"
    ];
    environment = {
      PORT = "3000";
      HOSTNAME = "127.0.0.1"; # bind address for the Next standalone server
      HOMEPAGE_CONFIG_DIR = "/var/lib/koderup-homepage";
      NIXPKGS_HOMEPAGE_CACHE_DIR = "/var/cache/koderup-homepage";
    };
    preStart = ''
      install -d -m 0755 /var/lib/koderup-homepage /var/cache/koderup-homepage
      cp -rT ${homepageConfig}/ /var/lib/koderup-homepage/
    '';
    serviceConfig = {
      Type = "simple";
      WorkingDirectory = "${pkgs.homepage-dashboard}/share/homepage";
      ExecStart = "${pkgs.homepage-dashboard}/bin/homepage";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
