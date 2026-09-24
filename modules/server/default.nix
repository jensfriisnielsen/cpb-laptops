{
  imports = [
    ./stay-awake.nix
    ./firewall.nix
    ./dns.nix
    ./podman.nix
    ./compose.nix
    ./traefik.nix
    ./services/homepage.nix
  ];
}
