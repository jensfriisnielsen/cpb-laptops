{ ... }:

# These ThinkPads use ALSA UCM HiFi. Speakers and headphones are separate
# UCM devices on the same analog card. Muting the ALSA "Speaker" mixer from
# a systemd timer makes the whole HiFi profile unavailable, so PipeWire
# falls back to Dummy Output and headphones die too.
#
# Disable only the built-in Speaker sink. Headphones (and HDMI / USB / BT)
# stay as normal PipeWire nodes.
{
  services.pipewire.wireplumber.extraConfig."51-disable-internal-speakers" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          {
            "node.name" = "~alsa_output.*HiFi__Speaker__sink";
          }
        ];
        actions = {
          update-props = {
            "node.disabled" = true;
          };
        };
      }
    ];
  };
}
