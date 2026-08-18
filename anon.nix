{ config, lib, pkgs, ... }:

{
  users.users.anon = {
    isNormalUser = true;
    description = "Anonymous";
    packages = with pkgs; [
      agg # gifs from asciinema
      asciinema # gifs and such from the terminal
      bat # like cat
      brave
      chromium
      doggo
      gimp
      inkscape
      krita
      libreoffice
      librewolf
      python3
      tree
      termshark # like wireshark just in the terminal
      unp # unpack any archive
      magic-wormhole # wormhole send anywhere
    ];
    password = "";
  };
}
