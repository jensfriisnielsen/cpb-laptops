# cpj-laptops


## Slides

A reveal.js deck on NixOS for teaching laptops lives in [`slides/`](slides/).
Open [`slides/index.html`](slides/index.html) in a browser.
See [`slides/README.md`](slides/README.md) for navigation keys and how to copy the folder onto a web server.

```sh
firefox slides/index.html
```

## Reconfiguring NixOS

The laptop should be connected to Netbird automatically

```sh
nixos-rebuild switch --flake .#koderup1 --target-host root@koderup1.netbird.cloud
```


## Installing NixOS

Following this guide for nixos-anywhere https://nix-community.github.io/nixos-anywhere/quickstart.html

The community installer image needs internet. On the administrator laptop, share WiFi over Ethernet first (see below), then install:

```sh
nix run github:nix-community/nixos-anywhere -- --extra-files nixos-anywhere-extra-files --flake .#koderup1 --target-host root@10.43.0.10
```

Replace `10.43.0.10` with the address in the DHCP leases file.

## Share WiFi over Ethernet

Administrator laptop only (GNOME/NetworkManager). This does **not** change managed laptop configs.

`share-eth` adds a separate NetworkManager profile named `koderup-share` (DHCP + NAT on `10.43.0.1/24`). It does not modify `Wired connection 1` or any other profile. When the cable has link, that profile comes up and the installer laptop gets an address automatically.

```sh
nix run .#share-eth -- up
```

Plug Ethernet into the machine booting the NixOS community image. Watch for a lease:

```sh
nix run .#share-eth -- status
cat /var/lib/NetworkManager/dnsmasq-*.leases
```

Tear down when finished. This deletes `koderup-share`, removes the `KODERUP-SHARE` iptables/ip6tables chain, and restores the ethernet profile that was active before `up`:

```sh
nix run .#share-eth -- down
```

Override the NIC with `ETH=enp0s31f6` if auto-detect picks the wrong device. From `nix develop`, `share-eth up` / `share-eth down` work the same.

`down` is safe to run when sharing is already off. Do not wrap the whole command in `sudo`; the script prompts only for the firewall rules.

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

## Speakers

Internal speakers stay off so classroom machines stay quiet. 3.5mm headphones, USB/Bluetooth headsets, and HDMI audio still work.

[`speakers.nix`](speakers.nix) tells WirePlumber to disable the ALSA UCM sink whose name matches `HiFi__Speaker__sink`.
On these ThinkPad T14s Gen 2a machines, speakers and headphones are two UCM devices on the same analog card (`Realtek ALC257`).
Disabling only that Speaker sink leaves the Headphones sink alone.

Do not mute the ALSA `Speaker` mixer from a boot script or timer. PipeWire then treats the whole HiFi profile as unavailable and GNOME shows **Dummy Output**, which also kills headphones.

With headphones plugged in, `wpctl status` (as the logged-in user) should list a Headphones sink, not Dummy Output.

