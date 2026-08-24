# General guidelines

- Use flake.nix to run project code
- Keep flake.nix and imported files up-to-date with project dependencies
- Devshell is for the administrators laptop and for pushing code
- The nixosConfigurations.koderup1 through koderup40 outputs are for managed laptops (same config, unique hostname)
- Per-host extras live in `hosts/<hostname>/` (`facter.json`, optional `default.nix`). Reuse another host with `hosts/from.nix`. Fleet-wide hardware default remains `./facter.json`.
- Dont mix code for managed and administrator laptops
- WiFi-to-Ethernet sharing for installer laptops is admin-only (`scripts/share-eth.sh`, `nix run .#share-eth`)
- Keep browser settings identical with the following exceptions:
  - librewolf is completely unmanaged
  - chromium does not have blocked websites
