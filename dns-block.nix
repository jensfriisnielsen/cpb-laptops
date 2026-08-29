# DNS block list for managed laptops.
# Each domain and its www. host are sinkholed via /etc/hosts (IPv4 + IPv6).
{ lib, ... }:
let
  blockedDomains = [
    "y8.com"
    "friv.com"
    "frivclassic.com"
    "x.com"
    "instagram.com"
    "facebook.com"
    "poki.com"
    "chatgpt.com"
    "claude.ai"
    "gemini.google.com"
    "grok.com"
  ];
  names = lib.unique (lib.concatMap (d: [ d "www.${d}" ]) blockedDomains);
in
{
  networking.hosts = {
    "0.0.0.0" = names;
    "::" = names;
  };
}
