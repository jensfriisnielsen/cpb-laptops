# General guidelines

- Use flake.nix to run project code
- Keep flake.nix and imported files up-to-date with project dependencies
- Devshell is for the administrators laptop and for pushing code
- The nixosConfigurations.koderup1 through koderup40 outputs are for managed laptops (same config, unique hostname)
- Dont mix code for managed and administrator laptops
- WiFi-to-Ethernet sharing for installer laptops is admin-only (`scripts/share-eth.sh`, `nix run .#share-eth`)
