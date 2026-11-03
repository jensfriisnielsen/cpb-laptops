# Bambuddy (Bambu Lab printer dashboard) on https://10.89.97.70/.
#
# The server uses a self-signed certificate (CN/SAN 10.89.97.70, no private
# key in this repo). Trust it system-wide and in Firefox, Chromium, and Brave
# so the browser opens the page without a warning. LibreWolf is unmanaged.
#
# The Dash launcher opens Bambuddy as a Chromium app window, like Tinkercad in
# ../bambu-studio.nix. The icon is the site's own android-chrome-192x192.png.
{ lib, pkgs, ... }:

let
  url = "https://10.89.97.70/";
  cert = ./bambuddy.crt;

  # Chromium's CACertificates policy wants base64 DER, i.e. the PEM body.
  certBase64 = lib.concatStrings (
    lib.filter (l: l != "" && !lib.hasPrefix "-----" l) (
      lib.splitString "\n" (lib.replaceStrings [ "\r" ] [ "" ] (builtins.readFile cert))
    )
  );

  bambuddy = pkgs.makeDesktopItem {
    name = "bambuddy";
    desktopName = "Bambuddy";
    comment = "Se og styr 3D-printerne";
    exec = "chromium --app=${url}";
    icon = "${./icon.png}";
    categories = [ "Utility" "Graphics" "3DGraphics" ];
    # Chromium derives this WM class from the --app URL; matching it lets GNOME
    # group the running window under the Dash launcher.
    startupWMClass = "chrome-10.89.97.70__-Default";
  };
in
{
  security.pki.certificateFiles = [ cert ];

  environment.etc."ssl/certs/bambuddy.crt".source = cert;

  programs.firefox.policies.Certificates.Install = [ "/etc/ssl/certs/bambuddy.crt" ];

  programs.chromium.extraOpts.CACertificates = [ certBase64 ];

  environment.systemPackages = [ bambuddy ];
}
