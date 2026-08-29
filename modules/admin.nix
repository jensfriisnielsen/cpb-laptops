{ config, lib, pkgs, ... }:

{
  users.users.admin = {
    isNormalUser = true;
    description = "Admin";
    extraGroups  = [ "wheel" "networkmanager" "dialout" ];
    hashedPasswordFile = config.sops.secrets."admin-hashed-password".path;
    openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;
  };
  sops.secrets."admin-hashed-password".neededForUsers = true;
}
