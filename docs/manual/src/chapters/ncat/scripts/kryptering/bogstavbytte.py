#!/usr/bin/env python3
"""Substitutions-kryptering: byt hvert bogstav ud med et andet.

I stedet for at flytte alfabetet et fast antal pladser (som i Cæsar-
kryptering), bestemmer du selv, hvilket bogstav hvert bogstav skal
blive til. Nøglen er en blanding af alle 29 bogstaver i det danske
alfabet (a-z samt æ, ø, å) — hvert bogstav skal bruges præcis én gang.
"""

import argparse
import sys

ALFABET = "abcdefghijklmnopqrstuvwxyzæøå"


def valider_noegle(noegle):
    if len(noegle) != len(ALFABET) or set(noegle) != set(ALFABET):
        raise SystemExit(
            "Nøglen skal være alle 29 bogstaver i det danske alfabet (a-z samt "
            "æ, ø, å) i en blandet rækkefølge, hvert bogstav præcis én gang. "
            "Fx: 'qwertyuiopåasdfghjklæøzxcvbnm' (det danske tastatur, række for "
            "række)."
        )


def byt_bogstaver(tekst, fra, til):
    tabel = str.maketrans(fra + fra.upper(), til + til.upper())
    return tekst.translate(tabel)


def main():
    parser = argparse.ArgumentParser(
        description="Substitutions-kryptering: byt hvert bogstav ud med et andet, "
        "ud fra en selvvalgt nøgle."
    )
    parser.add_argument(
        "besked",
        nargs="?",
        help="Beskeden, der skal krypteres/dekrypteres. Udelades for at læse "
        "fra standard input (stdin) — fx fra en ncat-pipe.",
    )
    parser.add_argument(
        "-n",
        "--noegle",
        required=True,
        help="29 bogstaver (a-z samt æ, ø, å) i blandet rækkefølge, fx "
        "'qwertyuiopåasdfghjklæøzxcvbnm'.",
    )
    parser.add_argument(
        "-d",
        "--dekrypter",
        action="store_true",
        help="Dekryptér i stedet for at kryptere (byt bogstaverne tilbage).",
    )
    args = parser.parse_args()

    valider_noegle(args.noegle)
    tekst = args.besked if args.besked is not None else sys.stdin.read().rstrip("\n")

    if args.dekrypter:
        print(byt_bogstaver(tekst, args.noegle, ALFABET))
    else:
        print(byt_bogstaver(tekst, ALFABET, args.noegle))


if __name__ == "__main__":
    main()
