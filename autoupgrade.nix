{ ... }:
{
  # Pull the flake from GitHub and switch. Hostname must match nixosConfigurations
  # (koderup1 … koderup40). Randomized delay spreads load across the fleet.
  system.autoUpgrade = {
    enable = true;
    flake = "github:jensfriisnielsen/cpb-laptops";
    flags = [ "--refresh" ];
    dates = "17:30";
    randomizedDelaySec = "45min";
    persistent = true;
    allowReboot = false;
    #rebootWindow = {
    #  lower = "02:00";
    #  upper = "06:00";
    #};
  };
}
