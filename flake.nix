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
      inherit (nixpkgs) lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      hostnames = map (i: "koderup${toString i}") (lib.range 1 40);

      # Administrator laptop only: share WiFi over Ethernet to installer machines.
      share-eth = pkgs.writeShellApplication {
        name = "share-eth";
        runtimeInputs = with pkgs; [
          coreutils
          gawk
          gnugrep
          iproute2
          iptables
        ];
        text = builtins.readFile ./scripts/share-eth.sh;
      };

      # Shared managed-laptop config; only networking.hostName differs per host.
      mkLaptop =
        hostname:
        lib.nixosSystem {
          modules = [
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            ./configuration.nix
            nixos-facter-modules.nixosModules.facter
            {
              networking.hostName = hostname;
              facter.reportPath =
                if builtins.pathExists ./facter.json then
                  ./facter.json
                else
                  throw "Have you forgotten to run nixos-anywhere with `--generate-hardware-config nixos-facter ./facter.json`?";
            }
          ];
        };
    in
    {
      nixosConfigurations = lib.genAttrs hostnames mkLaptop;

      packages.${system}.share-eth = share-eth;

      apps.${system}.share-eth = {
        type = "app";
        program = "${share-eth}/bin/share-eth";
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          git-crypt
          just
          ssh-to-age
          openssl
          share-eth
        ];
      };
    };
}
