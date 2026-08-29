# https://wiki.nixos.org/wiki/Inkscape
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    (inkscape-with-extensions.override {
      inkscapeExtensions = with inkscape-extensions; [ inkstitch ];
    })
  ];
}
