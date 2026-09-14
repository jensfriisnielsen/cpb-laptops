{ pkgs, ... }:
let
  kioskPage = pkgs.runCommand "koderup-kiosk-page" { } ''
    mkdir -p $out
    cp -r ${./kiosk-page}/* $out/
  '';

  kioskExtension = pkgs.runCommand "koderup-kiosk-extension" { } ''
    mkdir -p $out
    cp -r ${./kiosk-extension}/* $out/
  '';

  kioskPageServer = pkgs.writeShellApplication {
    name = "koderup-kiosk-page";
    runtimeInputs = with pkgs; [ python3 ];
    text = ''
      export KODERUP_KIOSK_PAGE=${kioskPage}
      export KODERUP_KIOSK_STATE="''${KODERUP_KIOSK_STATE:-/run/koderup-kiosk}"
      export KODERUP_KIOSK_HOST=127.0.0.1
      export KODERUP_KIOSK_PORT="''${KODERUP_KIOSK_PORT:-4173}"
      export KODERUP_KIOSK_BIN="${koderupKiosk}/bin/koderup-kiosk"
      exec python3 ${./kiosk-page/server.py}
    '';
  };

  kioskBrowser = pkgs.writeShellApplication {
    name = "koderup-kiosk-browser";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
      chromium
    ];
    text = ''
      export KODERUP_KIOSK_STATE="''${KODERUP_KIOSK_STATE:-/run/koderup-kiosk}"
      export KODERUP_KIOSK_USER=anon
      export KODERUP_KIOSK_EXTENSION=${kioskExtension}
      export KODERUP_KIOSK_CHROMIUM=${pkgs.chromium}/bin/chromium
      exec bash ${./kiosk-browser.sh}
    '';
  };

  koderupKiosk = pkgs.writeShellApplication {
    name = "koderup-kiosk";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      dconf
      dbus
      systemd
      util-linux
      python3
    ];
    text = ''
      export KODERUP_KIOSK_STATE="''${KODERUP_KIOSK_STATE:-/run/koderup-kiosk}"
      export KODERUP_KIOSK_PORT="''${KODERUP_KIOSK_PORT:-4173}"
      export KODERUP_KIOSK_USER=anon
      export KODERUP_KIOSK_BIN="${placeholder "out"}/bin/koderup-kiosk"
      exec bash ${./kiosk.sh} "$@"
    '';
  };

  kioskDesktop = pkgs.makeDesktopItem {
    name = "koderup-kiosk";
    desktopName = "Kiosk";
    comment = "Start Chromium i kiosk-tilstand";
    exec = "${koderupKiosk}/bin/koderup-kiosk start";
    icon = "preferences-desktop-display";
    categories = [
      "System"
      "Education"
    ];
    terminal = false;
  };
in
{
  environment.systemPackages = [
    koderupKiosk
    kioskPageServer
    kioskBrowser
    kioskDesktop
    pkgs.keyd
  ];

  # anon må starte/stoppe kiosk uden adgangskode.
  security.sudo.extraRules = [
    {
      users = [ "anon" ];
      commands = [
        {
          command = "${koderupKiosk}/bin/koderup-kiosk";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/koderup-kiosk";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  systemd.tmpfiles.rules = [
    "d /run/koderup-kiosk 0755 root root -"
    "d /run/koderup-kiosk/keyd 0755 root root -"
    "d /run/koderup-kiosk/profile 0755 anon users -"
  ];

  systemd.services.koderup-kiosk-keyd = {
    description = "Koderup kiosk keyboard lockdown (keyd)";
    path = [ pkgs.keyd ];
    serviceConfig = {
      Type = "simple";
      # Mount vores runtime-config over /etc/keyd for denne service.
      BindPaths = [ "/run/koderup-kiosk/keyd:/etc/keyd" ];
      ExecStart = "${pkgs.keyd}/bin/keyd";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  systemd.services.koderup-kiosk-page = {
    description = "Koderup kiosk demo page (localhost)";
    path = [
      koderupKiosk
      pkgs.python3
    ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${kioskPageServer}/bin/koderup-kiosk-page";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  # User unit så Chromium arver GNOME/Wayland-sessionen (ikke et root-system unit).
  systemd.user.services.koderup-kiosk-browser = {
    description = "Koderup kiosk Chromium";
    after = [ "graphical-session.target" ];
    path = [
      pkgs.chromium
      pkgs.util-linux
      pkgs.coreutils
      pkgs.bash
    ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${kioskBrowser}/bin/koderup-kiosk-browser";
      Restart = "no";
      KillMode = "control-group";
      TimeoutStopSec = 5;
    };
  };

  # Blokerer almindelig reboot/poweroff mens kiosk kører (ikke fysisk 4s-knap).
  systemd.services.koderup-kiosk-inhibit = {
    description = "Koderup kiosk shutdown inhibit";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=shutdown --who=koderup-kiosk --why='Kiosk-tilstand' --mode=block ${pkgs.coreutils}/bin/sleep infinity";
      Restart = "no";
    };
  };
}
