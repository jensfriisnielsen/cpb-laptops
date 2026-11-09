# Manden-i-midten

Denne side bygger videre på [Netværk og ncat: det grundlæggende](grundlaeggende.md) og
viser, hvordan man i en undervisningssituation kan illustrere et
**manden-i-midten**-angreb (man-in-the-middle, MITM).

> ⚠️ **Vigtigt — læs først!**
>
> Alt på denne side og på [Avanceret ncat: SSL og ARP-spoofing](avanceret.md) må
> **kun** bruges:
>
> - på skolens **egne** laptops,
> - i et **øvelsesnetværk** eller på et netværk, du selv ejer eller administrerer,
> - og **kun med din lærers udtrykkelige tilladelse**.
>
> At aflytte, forstyrre eller udgive sig for at være en anden på et netværk, du ikke
> har lov til at bruge, er **ulovligt** (Straffeloven) og kan få alvorlige
> konsekvenser. Eksemplerne her antager, at alle computere er jeres egne, og at alle
> deltagere har sagt ja. Formålet er at **lære, hvordan man beskytter sig** — ikke at
> genere nogen.

Forestil dig tre personer:

```
Elev A  ─────────────►  MitM-laptop  ─────────────►  Elev B
(afsender)               (lytter med)                (modtager)
```

**Elev A** tror, de taler direkte med **Elev B**. I virkeligheden går trafikken gennem
**MitM-laptoppen**, som kan læse og ændre det, der sendes. Det kaldes et
*man-in-the-middle*-angreb.

## Relay-angreb med ncat

Den nemmeste måde at lave øvelsen på: MitM-laptoppen er selv den "server", Elev A
forbinder til, og den videresender trafikken til Elev B. Elev A skal altså forbinde til
**MitM-laptoppens** adresse i stedet for Elev B's.

På **MitM-laptoppen** (indsæt Elev B's Netbird-adresse):

```sh
ncat -l 6000 --sh-exec "ncat 100.101.102.104 6000"
```

På **Elev B** (den rigtige server):

```sh
ncat -l 6000
```

På **Elev A**:

```sh
ncat 100.101.102.105 6000      # 105 er MitM-laptoppen, ikke Elev B
```

Alt, hvad Elev A skriver, havner hos Elev B — men MitM-laptoppen kan se det hele. Vil
du gemme det, der bliver sagt, kan du tilføje `--output`:

```sh
ncat -l 6000 --sh-exec "ncat 100.101.102.104 6000" \
  --output /tmp/aflytning.log
```

To mere virkelighedstro metoder — **ARP-spoofing** og **TLS-aflytning med mitmproxy** —
beskrives på næste side, [Avanceret ncat: SSL og ARP-spoofing](avanceret.md).

## Hvordan opdager man en manden-i-midten?

Her er det vigtigste ved hele øvelsen — **forsvaret**:

- **Certifikater skal tjekkes.** En browser eller et program skal advare, hvis
  certifikatet ikke passer. Klik aldrig "accepter alligevel" uden grund.
- **Netbird beskytter mellem peers.** Trafik mellem to Netbird-maskiner er krypteret og
  godkendt med WireGuard. Man kan altså ikke bare ARP-spoofe sig ind på den.
- **Kend dine peers.** `netbird status --detail` viser, hvem der er med i netværket.
  Er der en maskine med, som ikke burde være der, så sig det til din lærer.
- **Usædvanlige MAC-adresser.** To IP-adresser med samme MAC-adresse i `ip neigh` kan
  være et tegn på ARP-spoofing (se næste side).
- **Ukendte mellemled.** En tunnel, proxy eller "relay", du ikke selv har sat op, er
  mistænkelig.
- **`ncat --ssl` er ikke nok alene.** Det krypterer forbindelsen, men certifikatet skal
  stadig bekræftes ved en kendt og betroet kilde.

## Opgaver til eleverne

1. **Relay:** Sæt relay-angrebet op med tre laptops. Kan I se forskel på
   MitM-laptoppens log og den rigtige samtale? Hvornår ville I opdage det som bruger?
2. **Forsvar:** Forklar med egne ord, hvorfor ARP-spoofing ikke virker mod Netbird, og
   hvad man selv kan gøre for at opdage en manden-i-midten.

Næste side: [Python-kryptering af beskeder](python-kryptering.md).
