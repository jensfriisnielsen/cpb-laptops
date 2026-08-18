# https://wiki.nixos.org/wiki/Firefox
# https://mozilla.github.io/policy-templates/
{ ... }:

let
  amoLatest = slug: "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
in
{
  programs.firefox = {
    enable = true;
    policies = {
      DontCheckDefaultBrowser = true;
      # Skip Mozilla's first-run tour so the start page is what actually opens.
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";

      Homepage = {
        URL = "https://programmering.notion.site/";
        Locked = true;
        StartPage = "homepage";
      };

      SearchEngines = {
        Add = [
          {
            Name = "Qwant";
            URLTemplate = "https://www.qwant.com/?q={searchTerms}&client=opensearch";
            Method = "GET";
            IconURL = "https://www.qwant.com/favicon.ico";
            Alias = "@qwant";
            Description = "Qwant search";
            SuggestURLTemplate = "https://api.qwant.com/v3/suggest/?q={searchTerms}&client=opensearch";
          }
        ];
        Default = "Qwant";
      };

      ExtensionSettings = {
        # uBlock Origin — https://github.com/gorhill/uBlock#ublock-origin
        "uBlock0@raymondhill.net" = {
          install_url = amoLatest "ublock-origin";
          installation_mode = "force_installed";
        };
        # Consent-O-Matic — https://github.com/cavi-au/Consent-O-Matic
        "gdpr@cavi.au.dk" = {
          install_url = amoLatest "consent-o-matic";
          installation_mode = "force_installed";
        };
        # Privacy Badger — https://privacybadger.org/
        "jid1-MnnxcxisBPnSXQ@jetpack" = {
          install_url = amoLatest "privacy-badger17";
          installation_mode = "force_installed";
        };
      };
    };
  };
}
