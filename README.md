# cpj-laptops


## Slides

A reveal.js deck on NixOS for teaching laptops lives in [`slides/`](slides/).
Open [`slides/index.html`](slides/index.html) in a browser.
See [`slides/README.md`](slides/README.md) for navigation keys and how to copy the folder onto a web server.

```sh
firefox slides/index.html
```

## Reconfiguring NixOS

```sh
nixos-rebuild switch --flake .#lenovo --target-host root@192.168.1.188
```


## Installing NixOS

Following this guide for nixos-anywhere https://nix-community.github.io/nixos-anywhere/quickstart.html

```sh
nix run github:nix-community/nixos-anywhere -- --extra-files nixos-anywhere-extra-files --generate-hardware-config nixos-facter ./facter.json  --flake .#lenovo --target-host root@192.168.1.188
```

## Development

Enter the development environment

```sh
nix develop
```

## Secrets

Unlock the git-crypt encrypted secrets required for nixos-anywhere

```sh
make unlock
```

Edit sops secrets

```sh
sops secrets/sops-secrets.yaml
```
netbird-setup-key is required to connect to netbird in order to be able to provision NixOS over SSH

Note:
id_ed25519 SSH keys was used to generate the laptop age keys required on the laptop for sops activation decryption.

## HashedPasswords

```sh
nix-shell -p mkpasswd --run 'echo -n "yourpassword" | mkpasswd -s' | tr -d '\n'
```
