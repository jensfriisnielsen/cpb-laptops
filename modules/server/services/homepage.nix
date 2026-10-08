# First service. Later services show up from their homepage.* labels.
{ pkgs, ... }:
let
  settings = pkgs.writeText "homepage-settings.yaml" ''
    title: Koderup
    providers:
      docker:
        podman:
          socket: /var/run/docker.sock
          watch: true
  '';
in
{
  koderup.compose.services.homepage = {
    image = "ghcr.io/gethomepage/homepage:latest";
    restart = "unless-stopped";
    user = "0:0";
    networks = [ "koderup" ];
    environment.HOMEPAGE_ALLOWED_HOSTS = "home.koderup.dk,koderup.dk";
    volumes = [
      "/run/podman/podman.sock:/var/run/docker.sock:ro"
      "${settings}:/app/config/settings.yaml:ro"
    ];
    labels = [
      "traefik.enable=true"
      "traefik.http.routers.homepage.rule=Host(`home.koderup.dk`) || Host(`koderup.dk`)"
      "traefik.http.routers.homepage.entrypoints=websecure"
      "traefik.http.routers.homepage.tls=true"
      "traefik.http.services.homepage.loadbalancer.server.port=3000"
      "homepage.group=Koderup"
      "homepage.name=Homepage"
      "homepage.icon=homepage.png"
      "homepage.href=https://home.koderup.dk"
      "homepage.description=Services on koderup.dk"
    ];
  };
}
