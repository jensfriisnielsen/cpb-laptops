# Chromium-family policies.
# programs.chromium writes the same JSON to Chromium, Chrome, and Brave.
# Shared: privacy extensions only. Brave-only classroom policy lives in a
# separate file so Chromium does not get Qwant or the YouTube URL block.
# https://wiki.nixos.org/wiki/Chromium
# https://chromeenterprise.google/policies/
{ ... }:

{
  programs.chromium = {
    enable = true;
    extraOpts.ManagedBookmarks = import ./classroom-bookmarks.nix;
    extensions = [
      "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
      "mdjildafknihdffpkfmmpnpoiajfjnjd" # Consent-O-Matic
      "pkehgijcmpdhfbdbbnkijodmdjhbjlgp" # Privacy Badger
    ];
  };

  environment.etc."brave/policies/managed/classroom.json".text = builtins.toJSON {
    DefaultBrowserSettingEnabled = false;
    HomepageLocation = "https://programmering.notion.site/";
    HomepageIsNewTabPage = false;
    RestoreOnStartup = 4;
    RestoreOnStartupURLs = [ "https://programmering.notion.site/" ];
    DefaultSearchProviderEnabled = true;
    DefaultSearchProviderName = "Qwant";
    DefaultSearchProviderSearchURL = "https://www.qwant.com/?q={searchTerms}&client=opensearch";
    DefaultSearchProviderSuggestURL = "https://api.qwant.com/v3/suggest/?q={searchTerms}&client=opensearch";
    URLBlocklist = [
      "youtube.com"
      "youtu.be"
      "youtube-nocookie.com"
    ];
  };
}
