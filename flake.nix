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
      # Hostname -> other hostname whose hosts/<name>/ tree to reuse.
      hostFrom = import ./hosts/from.nix;

      hostDir = name: ./hosts + "/${name}";

      hardwareSource = hostname: hostFrom.${hostname} or hostname;

      facterFor =
        hostname:
        let
          source = hardwareSource hostname;
          local = hostDir hostname + "/facter.json";
          inherited = hostDir source + "/facter.json";
        in
        if builtins.pathExists local then
          local
        else if source != hostname && builtins.pathExists inherited then
          inherited
        else if builtins.pathExists ./facter.json then
          ./facter.json
        else
          throw ''
            Missing hardware report for ${hostname}.
            Add hosts/${hostname}/facter.json, inherit via hosts/from.nix, or keep ./facter.json as the fleet default.
            nixos-anywhere --generate-hardware-config nixos-facter ./hosts/${hostname}/facter.json
          '';

      # Host NixOS modules: inherited directory first, then this host's default.nix.
      hostModules =
        hostname:
        let
          source = hardwareSource hostname;
          inheritedNix = hostDir source + "/default.nix";
          ownNix = hostDir hostname + "/default.nix";
        in
        lib.optional (source != hostname && builtins.pathExists inheritedNix) inheritedNix
        ++ lib.optional (builtins.pathExists ownNix) ownNix;

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

      # Shared managed-laptop config; hostname, facter, and optional hosts/<name> modules differ.
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
              facter.reportPath = facterFor hostname;
            }
          ]
          ++ hostModules hostname;
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
