{ config, pkgs, lib, ... }:

{
  # This will add secrets.yml to the nix store
  # You can avoid this by adding a string to the full path instead, i.e.
  # sops.defaultSopsFile = "/root/.sops/secrets/example.yaml";
  sops.defaultSopsFile = ./secrets/sops-secrets.yaml;
  # This will automatically import SSH keys as age keys
  #sops.age.sshKeyPaths = [ ];
  # This is using an age key that is expected to already be in the filesystem
  sops.age.keyFile = "/var/lib/sops-nix/age-private-key.txt";
  # This will generate a new key if the key specified above does not exist
  sops.age.generateKey = false;
  # This is the actual specification of the secrets.
  sops.secrets = {
    "netbird-setup-key" = {};
  };
}
