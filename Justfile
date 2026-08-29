default_target:='192.168.1.249'

rebuild HOST:
    nixos-rebuild switch --flake ".#{{HOST}}" --target-host "root@{{HOST}}.netbird.cloud"

provision HOST TARGET=default_target:
    mkdir -p ./hosts/{{HOST}}
    nix run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-facter ./hosts/{{HOST}}/facter.json --extra-files nixos-anywhere-extra-files --flake ".#{{HOST}}" --target-host "root@{{TARGET}}"
