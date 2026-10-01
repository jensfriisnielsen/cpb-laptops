# Kiosk-tilstand

**Kiosk** er en særlig tilstand, hvor Chromium åbner i fuld skærm — uden adresselinje
og uden at man kan komme ud på skrivebordet. Det bruger I fx til præsentationer, eller
når en hjemmeside skal stå alene på skærmen.

## Start og stop

- **Klik på Kiosk-ikonet i docken.** Det starter kiosken.
- Vælg sværhedsgrad på knapperne på demo-siden: **Let**, **Mellem**, **Svær** eller
  **Tilfældig**. Tilfældig er standard.
- For at **stoppe** kiosken: se under "Hvis kiosken hænger" nedenfor.

## Hints

På demo-siden kan du få **hints** — små hjælpetekster om, hvilke "flugtveje" der
virker. Læreren kan skjule dem hvis det ønskes.

## Hvad er en "flugtvej"?

Kiosken prøver at holde dig inde på siden, men mange genveje kan stadig slippe dig ud
til skrivebordet — fx:

- **Super** (Windows-tasten) — aktiviteter
- **Alt+Tab** — skift vindue
- **Alt+F4 / Ctrl+W** — luk browseren
- **Ctrl+N / Ctrl+T** — nyt vindue
- **F12** — udviklerværktøjer
- **Højreklik** — menu
- **Ctrl+O / S / P** — fil-vinduer
- **Ctrl+Alt+F1–F6** — tekstterminal
- **Alt+F2** — kør kommando
- **Genstart / sluk** — og **USB** kan åbne Filer

Læreren kan vælge sværhedsgrad, så fx **Let** giver de fleste flugtveje, mens **Svær**
blokerer næsten alle.

## Hvis kiosken hænger

Åbn **Terminal** (eller brug en anden flugtvej) og skriv:

```sh
koderup-kiosk status
koderup-kiosk stop
```

Videre til [Opdater systemet](opdater-systemet.md).