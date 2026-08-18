# cpj-laptops

Slides
======

A reveal.js deck on NixOS for teaching laptops lives in [`slides/`](slides/).
Open [`slides/index.html`](slides/index.html) in a browser.
See [`slides/README.md`](slides/README.md) for navigation keys and how to copy the folder onto a web server.

```sh
firefox slides/index.html
```

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
