# General guidelines

- Use flake.nix to run project code
- Keep flake.nix and imported files up-to-date with project dependencies
- Devshell is for the administrators laptop and for pushing code
- The nixosConfigurations.lenovo = nixpkgs.lib.nixosSystem configurations are for managed laptops
- Dont mix code for managed and administrator laptops
