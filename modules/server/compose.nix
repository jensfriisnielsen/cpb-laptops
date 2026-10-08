# Merges koderup.compose.services into one Compose project and starts it
# after Netbird is up. Each service is its own Nix file.
{ config, lib, pkgs, ... }:
let
  secretsFile = ../../secrets/koderup.yaml;
  hasSecrets = builtins.pathExists secretsFile;
  yaml = pkgs.formats.yaml { };
  composeFile = yaml.generate "compose.yml" {
    networks.koderup.name = "koderup";
    services = config.koderup.compose.services;
  };
in
{
  options.koderup.compose.services = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Compose services merged into the koderup stack.";
  };

  config = lib.mkIf (hasSecrets && config.koderup.compose.services != { }) {
    systemd.services.koderup-compose = {
      description = "koderup Podman Compose stack";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "netbird.service"
        "sops-install-secrets.service"
      ];
      wants = [
        "network-online.target"
        "sops-install-secrets.service"
      ];
      path = with pkgs; [
        podman
        docker-compose
        iproute2
      ];
      environment = {
        PODMAN_COMPOSE_PROVIDER = "${pkgs.docker-compose}/bin/docker-compose";
        PODMAN_COMPOSE_WARNING_LOGS = "false";
        DOCKER_HOST = "unix:///run/podman/podman.sock";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "300";
        ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 60); do ip link show wt0 >/dev/null 2>&1 && exit 0; sleep 2; done; echo wt0 did not appear >&2; exit 1'";
        ExecStart = "${pkgs.podman}/bin/podman compose --file ${composeFile} up -d --remove-orphans";
        ExecStop = "${pkgs.podman}/bin/podman compose --file ${composeFile} down";
      };
    };
  };
}
