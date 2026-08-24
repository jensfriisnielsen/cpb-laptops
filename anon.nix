{ config, lib, pkgs, ... }:

{
  users.users.anon = {
    isNormalUser = true;
    description = "KodePirat";
    packages = with pkgs; [
      agg # gifs from asciinema
      asciinema # gifs and such from the terminal
    ];
    password = "";
  };
}
