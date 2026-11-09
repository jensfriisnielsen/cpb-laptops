#!/usr/bin/env python3
"""RSA i lille skala.

Dette er den samme matematik som "rigtig" RSA-kryptering: man vælger to
primtal p og q, ganger dem sammen til n = p * q, og bruger n til at lave
et offentligt nøglepar (n, e) og en hemmelig nøgle (n, d). Alle kan
kryptere med den offentlige nøgle, men kun den, der kender d, kan
dekryptere.

Sikkerheden hænger alene på, at det er svært at finde p og q ud fra n
alene (at "faktorisere" n). Her bruger vi med vilje meget små primtal,
så n kan faktoriseres på et øjeblik med kommandoen "knaek" — det er
pointen! Rigtig RSA bruger primtal med flere hundrede cifre, så den
samme udregning ville tage længere end universets levetid.
"""

import argparse
import math
import sys


def er_primtal(n):
    if n < 2:
        return False
    for i in range(2, int(math.isqrt(n)) + 1):
        if n % i == 0:
            return False
    return True


def modulaer_invers(e, phi):
    """Udvidet Euklids algoritme: find d, så (e * d) % phi == 1."""
    gammelt_r, r = e, phi
    gammelt_s, s = 1, 0
    while r != 0:
        kvotient = gammelt_r // r
        gammelt_r, r = r, gammelt_r - kvotient * r
        gammelt_s, s = s, gammelt_s - kvotient * s
    return gammelt_s % phi


def lav_noegler(p, q):
    if not (er_primtal(p) and er_primtal(q)):
        raise SystemExit("Både p og q skal være primtal.")
    if p == q:
        raise SystemExit("Vælg to forskellige primtal.")
    n = p * q
    if n <= 255:
        raise SystemExit(
            f"p * q = {n} er for lille — vælg primtal, så p * q > 255 "
            "(ellers kan et bogstav ikke pakkes ind i ét tal)."
        )
    phi = (p - 1) * (q - 1)
    e = 3
    while math.gcd(e, phi) != 1:
        e += 2
    d = modulaer_invers(e, phi)
    return n, e, d


def knaek_n(n):
    """Find p og q ud fra n alene, ved at prøve alle tal op til kvadratroden."""
    for i in range(2, int(math.isqrt(n)) + 1):
        if n % i == 0:
            return i, n // i
    return None


def krypter_tekst(tekst, n, e):
    return [pow(byte, e, n) for byte in tekst.encode("utf-8")]


def dekrypter_tal(tal, n, d):
    return bytes(pow(c, d, n) for c in tal).decode("utf-8")


def tekst_til_tal(tekst):
    return [int(stk) for stk in tekst.strip().split(",") if stk.strip()]


def tal_til_tekst(tal):
    return ",".join(str(t) for t in tal)


def hent_tekst(besked):
    return besked if besked is not None else sys.stdin.read().rstrip("\n")


def main():
    parser = argparse.ArgumentParser(
        description="RSA i lille skala: offentlig/hemmelig nøgle-kryptering med "
        "så små primtal, at den kan knækkes på et øjeblik."
    )
    underkommandoer = parser.add_subparsers(dest="kommando", required=True)

    p_noegler = underkommandoer.add_parser(
        "noegler", help="Lav et nøglepar ud fra to primtal p og q."
    )
    p_noegler.add_argument("--p", type=int, default=61, help="Første primtal. Standard: 61.")
    p_noegler.add_argument("--q", type=int, default=53, help="Andet primtal. Standard: 53.")

    p_krypter = underkommandoer.add_parser(
        "krypter", help="Kryptér en besked med den offentlige nøgle (n, e)."
    )
    p_krypter.add_argument("--n", type=int, required=True)
    p_krypter.add_argument("--e", type=int, required=True)
    p_krypter.add_argument(
        "besked",
        nargs="?",
        help="Beskeden. Udelades for at læse fra standard input (stdin).",
    )

    p_dekrypter = underkommandoer.add_parser(
        "dekrypter", help="Dekryptér en besked med den hemmelige nøgle (n, d)."
    )
    p_dekrypter.add_argument("--n", type=int, required=True)
    p_dekrypter.add_argument("--d", type=int, required=True)
    p_dekrypter.add_argument(
        "kryptotekst",
        nargs="?",
        help="Krypteret tekst som kommaseparerede tal. Udelades for stdin.",
    )

    p_knaek = underkommandoer.add_parser(
        "knaek",
        help="Angrib: find p, q og d ud fra kun den offentlige nøgle (n, e).",
    )
    p_knaek.add_argument("--n", type=int, required=True)
    p_knaek.add_argument("--e", type=int, required=True)
    p_knaek.add_argument(
        "--kryptotekst",
        help="Krypteret tekst (kommaseparerede tal), hvis du vil dekryptere den med det samme.",
    )

    args = parser.parse_args()

    if args.kommando == "noegler":
        n, e, d = lav_noegler(args.p, args.q)
        print(f"n = {n}")
        print(f"e = {e}")
        print(f"d = {d}")
        print(f"Offentlig nøgle (deles med alle): n={n}, e={e}")
        print(f"Hemmelig nøgle (holdes for dig selv): n={n}, d={d}")

    elif args.kommando == "krypter":
        tekst = hent_tekst(args.besked)
        tal = krypter_tekst(tekst, args.n, args.e)
        print(tal_til_tekst(tal))

    elif args.kommando == "dekrypter":
        kryptotekst = hent_tekst(args.kryptotekst)
        tal = tekst_til_tal(kryptotekst)
        print(dekrypter_tal(tal, args.n, args.d))

    elif args.kommando == "knaek":
        fundet = knaek_n(args.n)
        if fundet is None:
            raise SystemExit(f"Kunne ikke faktorisere n={args.n} — er det virkelig et produkt af to primtal?")
        p, q = fundet
        phi = (p - 1) * (q - 1)
        d = modulaer_invers(args.e, phi)
        print(f"n={args.n} = {p} * {q}")
        print(f"Udregnet hemmelig nøgle: d={d}")
        if args.kryptotekst:
            tal = tekst_til_tal(args.kryptotekst)
            print(f"Dekrypteret besked: {dekrypter_tal(tal, args.n, d)}")


if __name__ == "__main__":
    main()
