# Traefik terminates TLS for koderup.dk.
# The full chain is the public git-crypt file. Only the leaf key is sops.
{ config, lib, pkgs, ... }:
let
  secretsFile = ../../secrets/koderup.yaml;
  fullchain = ../../secrets/mkcert/koderup-fullchain.crt;
  hasSecrets = builtins.pathExists secretsFile && builtins.pathExists fullchain;
  tlsFile = pkgs.writeText "koderup-traefik-tls.yml" ''
    tls:
      certificates:
        - certFile: /certs/koderup.crt
          keyFile: /certs/koderup.key
      stores:
        default:
          defaultCertificate:
            certFile: /certs/koderup.crt
            keyFile: /certs/koderup.key
  '';
in
{
  config = lib.mkIf hasSecrets {
    sops.secrets."koderup-tls-key" = {
      sopsFile = secretsFile;
      mode = "0400";
    };

    koderup.compose.services.traefik = {
      image = "docker.io/library/traefik:v3";
      restart = "unless-stopped";
      networks = [ "koderup" ];
      ports = [
        "80:80"
        "443:443"
      ];
      command = [
        "--providers.docker=true"
        "--providers.docker.exposedbydefault=false"
        "--providers.docker.network=koderup"
        "--providers.file.filename=/etc/traefik/tls.yml"
        "--providers.file.watch=true"
        "--entrypoints.web.address=:80"
        "--entrypoints.websecure.address=:443"
        "--entrypoints.web.http.redirections.entrypoint.to=websecure"
        "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      ];
      volumes = [
        "/run/podman/podman.sock:/var/run/docker.sock:ro"
        "${tlsFile}:/etc/traefik/tls.yml:ro"
        "${fullchain}:/certs/koderup.crt:ro"
        "${config.sops.secrets."koderup-tls-key".path}:/certs/koderup.key:ro"
      ];
    };
  };
}
