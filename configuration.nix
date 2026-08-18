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
    ./speakers.nix
  ];

  services.flatpak.enable = true;

  # GNOME and such
  services.udev.packages = with pkgs; [ gnome-settings-daemon ];
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
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "da_DK.UTF-8";
    LC_IDENTIFICATION = "da_DK.UTF-8";
    LC_MEASUREMENT = "da_DK.UTF-8";
    LC_MONETARY = "da_DK.UTF-8";
    LC_NAME = "da_DK.UTF-8";
    LC_NUMERIC = "da_DK.UTF-8";
    LC_PAPER = "da_DK.UTF-8";
    LC_TELEPHONE = "da_DK.UTF-8";
    LC_TIME = "da_DK.UTF-8";
  };

  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  boot.loader.systemd-boot.configurationLimit = 10;
  
  nix.settings.trusted-users = [ "root" "jef" ];
  nix.settings.max-jobs = 4; # 8 cpus
  nix.settings.use-cgroups = true; # supposedly enables resource limits for builders https://discourse.nixos.org/t/nix-build-ate-my-ram/35752
  nix.settings.experimental-features = [ "nix-command" "flakes" "cgroups" ];
  
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "yes";
      AllowUsers = [ "admin" ];
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

  system.stateVersion = "26.11";
}
