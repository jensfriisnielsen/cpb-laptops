# Colyseus multiplayer (https://docs.colyseus.io)
# Node.js + npm so laptops can scaffold and run a Colyseus server
# (`npm create colyseus-app@latest`, then `npm start` on port 2567).
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    nodejs
  ];

  # Default Colyseus listen port so other classroom machines can connect.
  networking.firewall.allowedTCPPorts = [ 2567 ];
}
