# cpj-laptops

Reconfiguring NixOS
===================

```sh
nixos-rebuild switch --flake ./flake.nix#lenovo --target-host root@192.168.1.188
```


Installing NixOS
================

Following this guide for nixos-anywhere https://nix-community.github.io/nixos-anywhere/quickstart.html

```
nix run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-facter ./facter.json  --flake ./flake.nix#lenovo --target-host root@192.168.1.188
```
