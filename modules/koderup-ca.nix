# Trust the koderup CA in Firefox, Chromium, and Brave.
# The CA certificate is public and lives in secrets/mkcert (git-crypt).
# LibreWolf is unmanaged and does not get this CA.
{ lib, ... }:
let
  ca = ../secrets/mkcert/rootCA.pem;
  hasCa = builtins.pathExists ca;
in
{
  config = lib.mkIf hasCa {
    security.pki.certificateFiles = [ ca ];

    environment.etc."ssl/certs/koderup-ca.crt".source = ca;

    programs.firefox.policies.Certificates = {
      ImportEnterpriseRoots = true;
      Install = [ "/etc/ssl/certs/koderup-ca.crt" ];
    };
  };
}
