{ config, pkgs, ... }:

let
  # Unencrypted GKeyFile format (empty master password). Do not name this
  # login.keyring: gnome-keyring re-encrypts that collection to the login
  # password on write, which autologin never provides.
  emptyKeyring = pkgs.writeText "Default_keyring.keyring" ''
    [keyring]
    display-name=Default keyring
    ctime=0
    mtime=0
    lock-on-idle=false
    lock-after=false
  '';
in
{
  users.users.anon = {
    isNormalUser = true;
    description = "KodePirat";
    extraGroups = [ "dialout" ]; # USB serial (SPIKE / ttyACM*) for Web Serial
    packages = with pkgs; [
      agg # gifs from asciinema
      asciinema # gifs and such from the terminal
    ];
    password = "";
  };

  # Autologin has no PAM password, so apps would prompt "password for new
  # keyring". Seed an empty default keyring before GDM starts the session.
  # Create-if-missing only: never delete or rewrite existing keyrings, so
  # autoupgrade cannot wipe secrets apps have stored.
  systemd.services.anon-empty-keyring = {
    description = "Seed passwordless GNOME keyring for anon";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      user=anon
      group=${config.users.users.anon.group}
      dir=/home/anon/.local/share/keyrings
      install -d -m 0700 -o "$user" -g "$group" "$dir"

      if [ ! -f "$dir/Default_keyring.keyring" ]; then
        install -m 0600 -o "$user" -g "$group" ${emptyKeyring} "$dir/Default_keyring.keyring"
      fi

      if [ ! -e "$dir/default" ]; then
        printf '%s\n' 'Default_keyring.keyring' >"$dir/default"
        chown "$user:$group" "$dir/default"
        chmod 0600 "$dir/default"
      fi
    '';
  };
}
