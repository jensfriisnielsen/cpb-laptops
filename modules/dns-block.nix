# DNS block list for managed laptops.
# Each domain and its www. host are sinkholed via /etc/hosts (IPv4 + IPv6).
# Note: /etc/hosts has no wildcards, so this only catches the apex + www.
# host, not arbitrary subdomains. YouTube is blocked via browser policy
# (see modules/firefox.nix / modules/chromium.nix), not here.
{ lib, ... }:
let
  blockedDomains = [
    # Social media
    "x.com"
    "instagram.com"
    "facebook.com"
    "tiktok.com"
    "snapchat.com"
    "discord.com"

    # AI chatbots
    "chatgpt.com"
    "claude.ai"
    "gemini.google.com"
    "grok.com"
    "perplexity.ai"
    "character.ai"
    "poe.com"
    "copilot.microsoft.com"
    "meta.ai"
    "deepseek.com"

    # Game portals
    "y8.com"
    "friv.com"
    "frivclassic.com"
    "poki.com"
    "crazygames.com"
    "coolmathgames.com"
    "coolmath-games.com"
    "miniclip.com"
    "addictinggames.com"
    "kizi.com"
    "agame.com"
    "gamesgames.com"
    "silvergames.com"
    "kongregate.com"
    "armorgames.com"
    "lagged.com"
    "kevin.games"
    "itch.io"

    # Unity WebGL / HTML5 game platforms and CDNs (many "unblocked games"
    # mirrors just embed one of these underneath)
    "simmer.io"
    "unityroom.com"
    "gamedistribution.com"
    "gamepix.com"
    "famobi.com"
    "html5games.com"
    "twoplayergames.org"
    "girlsgogames.com"
    "gahe.com"
    "gameflare.com"
    "brightestgames.com"

    # "Unblocked games" hubs
    "classroom6x.com"
    "unblockedgames.com"
    "unblockedgames66.com"
    "unblockedgames76.com"
    "unblockedgames77.com"
    "unblockedgames911.com"

    "whatbeatsrock.com"

    # Cloud gaming / in-browser proxies (used to bypass other blocks)
    "now.gg"
    "mathsspot.com"
    "neal.fun"

    # Roblox
    "roblox.com"

    # Slope and its mirrors
    "slope3.com"
    "slopeio.org"
    "slope-game.io"
    "slopegame.io"
    "slope-game.com"
    "slope-game.org"
    "slope2-game.com"
    "slope2-game.io"
    "slope2.online"
    "slope2run.io"

    # Other trending browser games
    "1v1.lol"
    "retrobowl.me"
    "retro-bowl.com"
    "coolgamesfree.org"

    # ".io games" (browser multiplayer genre named after the TLD)
    "agar.io"
    "slither.io"
    "diep.io"
    "krunker.io"
    "paper.io"
    "paper-io.com"
    "shellshock.io"
    "surviv.io"
    "wilds.io"
    "zombsroyale.io"
    "venge.io"
    "starve.io"
    "florr.io"
    "moomoo.io"
    "deeeep.io"
    "hole.io"
    "ev.io"
    "powerline.io"
    "mope.io"
    "wormax.io"
    "generals.io"
    "skribbl.io"
    "1001games.com"
    "freegames.com"
    "fnaffree.io"
  ];
  names = lib.unique (lib.concatMap (d: [ d "www.${d}" ]) blockedDomains);
in
{
  networking.hosts = {
    "0.0.0.0" = names;
    "::" = names;
  };
}
