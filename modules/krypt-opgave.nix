# The Python ciphers from the ncat/python-kryptering manual chapter
# (docs/manual/src/chapters/ncat/scripts/kryptering/), installed globally so
# students can run them from any terminal without `cd`-ing to the scripts or
# typing out `python3 .../caesar.py`. Same source files the manual includes
# verbatim with {{#include}}, so the code students read is the code that runs.
{ pkgs, ... }:

let
  scripts = ../docs/manual/src/chapters/ncat/scripts/kryptering;

  krypt-opgave = pkgs.stdenv.mkDerivation {
    pname = "krypt-opgave";
    version = "1.0.0";
    src = scripts;
    dontUnpack = true;
    dontBuild = true;
    nativeBuildInputs = [ pkgs.python3 ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      install -m755 ${scripts}/caesar.py $out/bin/krypt-caesar
      install -m755 ${scripts}/bogstavbytte.py $out/bin/krypt-bogstavbytte
      install -m755 ${scripts}/rsa_lille.py $out/bin/krypt-rsa
      patchShebangs $out/bin
      runHook postInstall
    '';
  };
in
{
  environment.systemPackages = [ krypt-opgave ];
}
