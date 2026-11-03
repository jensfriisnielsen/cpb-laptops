# Fleet-wide desktop and lock-screen background, locked so users cannot
# change it (GNOME Settings shows the Background panel as read-only).
{ ... }:

let
  uri = "file://${./background.jpg}";
in
{
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/background" = {
          picture-uri = uri;
          picture-uri-dark = uri;
          picture-options = "zoom";
        };
        "org/gnome/desktop/screensaver" = {
          picture-uri = uri;
          picture-options = "zoom";
        };
      };
      locks = [
        "/org/gnome/desktop/background/picture-uri"
        "/org/gnome/desktop/background/picture-uri-dark"
        "/org/gnome/desktop/background/picture-options"
        "/org/gnome/desktop/background/primary-color"
        "/org/gnome/desktop/background/secondary-color"
        "/org/gnome/desktop/background/color-shading-type"
        "/org/gnome/desktop/screensaver/picture-uri"
        "/org/gnome/desktop/screensaver/picture-options"
      ];
    }
  ];
}
