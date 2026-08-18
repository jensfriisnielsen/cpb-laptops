# https://wiki.nixos.org/wiki/Netbird
{ config, lib, pkgs, ... }:

{
  services.resolved.enable = true;

  services.netbird.enable = true;
  services.netbird.clients.default = {

    autoStart = true;
    # Automatically login to your Netbird network with a setup key
    # This is mostly useful for server computers.
    # For manual setup instructions, see the wiki page section below.
    login = {
      enable = true;

      # Path to a file containing the setup key for your peer
      # NOTE: if your setup key is reusable, make sure it is not copied to the Nix store.
      setupKeyFile = "/run/secrets/netbird-setup-key";
    };

    # Port used to listen to wireguard connections
    port = 51821;

    # Set this to true if you want the GUI client
    ui.enable = false;

    # This opens ports required for direct connection without a relay
    openFirewall = true;

    # This opens necessary firewall ports in the Netbird client's network interface
    openInternalFirewall = true;
  };

  sops.secrets."netbird-setup-key" = {};
}
