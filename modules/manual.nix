# Koderup laptop-manual (http://localhost:8888).
#
# Builds docs/manual (an mdBook site, Danish user manual) into the Nix store and
# serves it on every managed laptop — localhost only. Written to the laptop user.
#
# How it ships: docs/manual is a source dependency of the derivation below, so
# mdBook (from the locked nixpkgs) renders it during the NixOS config build. The
# rendered book is a store path referenced by the systemd unit, so laptops
# receive it as part of the system closure (nixos-rebuild / nixos-anywhere and
# the nightly autoUpgrade). The markdown itself never reaches a laptop.
{ pkgs, ... }:

let
  manualPages =
    pkgs.runCommand "koderup-manual"
      {
        nativeBuildInputs = [ pkgs.mdbook ];
      }
      ''
        mdbook build ${../docs/manual} --dest-dir "$out"
        # Fleet screenshots used by the chapters live in the repo docs/ root; copy
        # them next to the rendered pages so ../image.png resolves from chapters/.
        cp ${../docs}/*.png "$out/" 2>/dev/null || true
      '';
in
{
  systemd.services.koderup-manual = {
    description = "Koderup laptop-manual (http://localhost:8888)";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8888 --bind 127.0.0.1 --directory ${manualPages}";
      Restart = "on-failure";
      RestartSec = 3;
      # Static, read-only site.
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
