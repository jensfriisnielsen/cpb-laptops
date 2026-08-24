rebuild HOST:
    nixos-rebuild switch --flake ".#{{HOST}}" --target-host "root@{{HOST}}.netbird.cloud"
