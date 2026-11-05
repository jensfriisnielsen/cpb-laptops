# Python packages installed on the managed laptops. Add packages to the
# withPackages list below; they become importable by `python3`.
{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.python3.withPackages (ps: with ps; [
      pillow
      pip
      pygame
      tkinter
    ]))
  ];
}
