default_target:='192.168.1.249'

rebuild HOST:
    nixos-rebuild switch --flake ".#{{HOST}}" --target-host "root@{{HOST}}.netbird.cloud"

provision HOST TARGET=default_target:
    mkdir -p ./hosts/{{HOST}}
    nix run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-facter ./hosts/{{HOST}}/facter.json --extra-files nixos-anywhere-extra-files --flake ".#{{HOST}}" --target-host "root@{{TARGET}}"

certs:
    ./scripts/koderup-certs.sh

test:
    ./scripts/eval-hosts.sh

test-full:
    ./scripts/eval-hosts.sh --all

# Build + preview the laptop manual locally (mirrors the deployed
# http://localhost:8888 on the managed laptops).
manual:
    mdbook build ./docs/manual
    cp docs/*.png docs/manual/book/ || true
    python3 -m http.server 8888 --bind 127.0.0.1 --directory docs/manual/book
