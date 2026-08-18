{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
  inputs.sops-nix.url = "github:Mic92/sops-nix";
  inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    {
      nixpkgs,
      disko,
      nixos-facter-modules,
      sops-nix,
      ...
    }:
    let 
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      # Slightly experimental: Like generic, but with nixos-facter (https://github.com/numtide/nixos-facter)
      # nixos-anywhere --flake .#generic-nixos-facter --generate-hardware-config nixos-facter facter.json <hostname>
      nixosConfigurations.lenovo = nixpkgs.lib.nixosSystem {
        #system = ${system};
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./configuration.nix
          nixos-facter-modules.nixosModules.facter
          {
            config.facter.reportPath =
              if builtins.pathExists ./facter.json then
                ./facter.json
              else
                throw "Have you forgotten to run nixos-anywhere with `--generate-hardware-config nixos-facter ./facter.json`?";
          }
        ];
      };
      
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          git-crypt
          ssh-to-age
          openssl
        ];
      };
    };
}
