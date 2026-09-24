# Podman only. docker-compose talks to the Podman socket via `podman compose`.
{ pkgs, ... }:
{
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  environment.systemPackages = with pkgs; [
    docker-compose
    podman-compose
  ];

  environment.variables = {
    PODMAN_COMPOSE_PROVIDER = "${pkgs.docker-compose}/bin/docker-compose";
    PODMAN_COMPOSE_WARNING_LOGS = "false";
  };
}
