{
  modulesPath,
  lib,
  pkgs,
  ...
} @ args:
let
  sshAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEOJy1bCfyM+qtQ3RdR9DjeYffMuwcburCVJ/LKeNI0z jef2022passphrase"
  ];
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix # disk partitioning
    ./sops.nix # secrets
    ./admin.nix
    ./anon.nix
    ./netbird.nix
    ./firefox.nix
    #./speakers.nix
  ];

  services.flatpak.enable = true;
  services.displayManager.gdm.enable = true;
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "anon";
  services.desktopManager.gnome.enable = true;
  # Configure keymap in X11
  services.xserver.xkb.layout = "dk";
  services.xserver.xkb.variant = "";
  # Configure console keymap
  console.keyMap = "dk-latin1";
  # danish UI
  i18n.defaultLocale = "da_DK.UTF-8";

  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  
  services.openssh.enable = true;
    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "yes";
        #AllowUsers = [ "myUser" ];
        #MaxAuthTries = 3;
        #PerSourcePenalties = "crash:3600s authfail:3600s max:86400s";
      };
    };

  environment.systemPackages = with pkgs; [
    curl
    git
    vim
    tmux
  ];

  users.users.root.openssh.authorizedKeys.keys = sshAuthorizedKeys;
  users.mutableUsers = false;

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "26.05";
}
