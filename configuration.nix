{
  modulesPath,
  lib,
  pkgs,
  ...
} @ args:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ./anon.nix
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

  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    curl
    git
    vim
    tmux
  ];

  users.users.root.openssh.authorizedKeys.keys =
  [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEOJy1bCfyM+qtQ3RdR9DjeYffMuwcburCVJ/LKeNI0z jef2022passphrase"
  ];

  system.stateVersion = "25.11";
}
