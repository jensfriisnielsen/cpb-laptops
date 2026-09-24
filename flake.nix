{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
  inputs.sops-nix.url = "github:Mic92/sops-nix";
  inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";

  outputs =
    {
      nixpkgs,
      disko,
      nixos-facter-modules,
      sops-nix,
      nix-flatpak,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      hostnames = map (i: "koderup${toString i}") (lib.range 1 40);

      hostDir = name: ./hosts + "/${name}";

      facterFor =
        hostname:
        let
          local = hostDir hostname + "/facter.json";
        in
        if builtins.pathExists local then
          local
        else if builtins.pathExists ./facter.json then
          ./facter.json
        else
          throw ''
            Missing hardware report for ${hostname}.
            Add hosts/${hostname}/facter.json or keep ./facter.json as the fleet default.
            nixos-anywhere --generate-hardware-config nixos-facter ./hosts/${hostname}/facter.json
          '';

      hostModules =
        hostname:
        let
          ownNix = hostDir hostname + "/default.nix";
        in
        lib.optional (builtins.pathExists ownNix) ownNix;

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

      # Administrator laptop only: evaluate host configs without building.
      eval-hosts = pkgs.writeShellApplication {
        name = "eval-hosts";
        runtimeInputs = with pkgs; [ coreutils ];
        text = builtins.readFile ./scripts/eval-hosts.sh;
      };

      # Shared managed-laptop config; hostname, facter, and optional hosts/<name> modules differ.
      mkLaptop =
        hostname:
        lib.nixosSystem {
          modules = [
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            nix-flatpak.nixosModules.nix-flatpak
            ./modules/configuration.nix
            nixos-facter-modules.nixosModules.facter
            {
              networking.hostName = hostname;
              facter.reportPath = facterFor hostname;
            }
          ]
          ++ hostModules hostname;
        };
    in
    {
      nixosConfigurations = lib.genAttrs hostnames mkLaptop;

      packages.${system} = {
        inherit share-eth eval-hosts;
      };

      apps.${system} = {
        share-eth = {
          type = "app";
          program = "${share-eth}/bin/share-eth";
        };
        eval-hosts = {
          type = "app";
          program = "${eval-hosts}/bin/eval-hosts";
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          git-crypt
          just
          mkcert
          sops
          ssh-to-age
          openssl
          share-eth
          eval-hosts
        ];
      };
    };
}
