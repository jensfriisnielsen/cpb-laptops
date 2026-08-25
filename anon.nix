{ config, lib, pkgs, ... }:

{
  users.users.anon = {
    isNormalUser = true;
    description = "KodePirat";
    extraGroups = [ "dialout" ]; # USB serial (SPIKE / ttyACM*) for Web Serial
    packages = with pkgs; [
      agg # gifs from asciinema
      asciinema # gifs and such from the terminal
    ];
    password = "";
  };
}
