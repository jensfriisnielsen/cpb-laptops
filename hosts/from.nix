# Reuse another host directory (facter.json + default.nix).
# Example: koderup13 uses koderup12's hardware and host Nix modules.
# hosts/koderup13/default.nix is still imported if it exists (extra settings only;
# do not also `imports = [ ../koderup12 ]` or those modules load twice).
{
  koderup13 = "koderup12";
}
