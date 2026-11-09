#!/usr/bin/env python3
"""Cæsar-kryptering: flyt hvert bogstav et fast antal pladser i alfabetet.

Kun bogstaverne a-z/A-Z bliver flyttet. Mellemrum, tal, tegnsætning og
danske bogstaver (æøå) bliver ikke rørt.
"""

import argparse
import sys

ALFABET = "abcdefghijklmnopqrstuvwxyz"


def caesar(tekst, flyt):
    resultat = []
    for tegn in tekst:
        lille = tegn.lower()
        if lille in ALFABET:
            ny_plads = (ALFABET.index(lille) + flyt) % len(ALFABET)
            nyt_tegn = ALFABET[ny_plads]
            resultat.append(nyt_tegn.upper() if tegn.isupper() else nyt_tegn)
        else:
            resultat.append(tegn)
    return "".join(resultat)


def main():
    parser = argparse.ArgumentParser(
        description="Cæsar-kryptering: flyt hvert bogstav et fast antal pladser i alfabetet."
    )
    parser.add_argument(
        "besked",
        nargs="?",
        help="Beskeden, der skal krypteres/dekrypteres. Udelades for at læse "
        "fra standard input (stdin) — fx fra en ncat-pipe.",
    )
    parser.add_argument(
        "-f",
        "--flyt",
        type=int,
        default=3,
        help="Hvor mange pladser hvert bogstav flyttes (nøglen). Standard: 3.",
    )
    parser.add_argument(
        "-d",
        "--dekrypter",
        action="store_true",
        help="Dekryptér i stedet for at kryptere (flyt den anden vej).",
    )
    args = parser.parse_args()

    tekst = args.besked if args.besked is not None else sys.stdin.read().rstrip("\n")
    flyt = -args.flyt if args.dekrypter else args.flyt
    print(caesar(tekst, flyt))


if __name__ == "__main__":
    main()
