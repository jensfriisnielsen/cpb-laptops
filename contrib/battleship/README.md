# 🚢 Sænke Slagskibe – TUI-netværksspil

Et simpelt undervisningsprojekt hvor elever placerer skibe via en konfigurationsfil og derefter skyder på hinanden over netværket ved hjælp af **ncat** og **named pipes** (fifos).

## Koncept

- Hver elev har en **server** (`ncat -l`) og en **client** (`ncat <ip>`), der kommunikerer rå tekst (`FIRE B2`, `HIT B2`, `SUNK B2 Destroyer`, `WIN`).
- Spillet har en **TUI** (terminal-UI), der viser:
  - Dit eget bræt med dine skibe og modstanderens hits.
  - Modstanderens bræt, så du kan se dine egne hits/misses.
  - Et log-panel med netværksbeskeder.
- Spillet kommunikerer via to **fifos** (`--incoming` og `--outgoing`).
  - Det gør det muligt at se rå netværkstrafik **udenfor** spillet med `ncat` og `tee`.

## Installation

```bash
# Kør direkte fra repoet
nix run .#battleship -- --help
```

## Forberedelse – fifos

```bash
# Opret to named pipes
mkfifo in out
```

## Sådan starter du netværksforbindelsen

Den rigtige styrke er at netværksforbindelsen selv styres af eleverne **udenfor** spillet.

### Elev 1 (192.168.1.10)

Terminal 1 – modtag og vis rå trafik:
```bash
ncat -l 4000 | tee in
```

Terminal 2 – send rå trafik:
```bash
ncat 192.168.1.11 4000 < out
```

Terminal 3 – spillet:
```bash
nix run .#battleship -- --config ships.yaml --incoming in --outgoing out
```

### Elev 2 (192.168.1.11)

Terminal 1:
```bash
ncat -l 4000 | tee in
```

Terminal 2:
```bash
ncat 192.168.1.10 4000 < out
```

Terminal 3:
```bash
nix run .#battleship -- --config ships.yaml --incoming in --outgoing out
```

> 💡 **Tip:** Brug `--manual` hvis spillet ikke automatisk skal skrive til `out`.  
> Så viser spillet `FIRE B2` i TUI'en, og eleven kopierer selv kommandoen over i `ncat`.

## Konfigurationsfil (ships.yaml)

Se `examples/ships.yaml`. Alle fem skibe skal placeres inden for A1–J10 uden overlap.

```yaml
ships:
  - name: Carrier
    cell: A1
    direction: horizontal
  - name: Battleship
    cell: B1
    direction: horizontal
  - name: Cruiser
    cell: C1
    direction: horizontal
  - name: Submarine
    cell: D1
    direction: horizontal
  - name: Destroyer
    cell: E1
    direction: horizontal
```

## Protokol

Al kommunikation sker i **ren tekst** linje for linje:

| Besked | Beskrivelse |
|--------|-------------|
| `FIRE B2` | Affyr et skud på B2 |
| `HIT B2` | Skuddet ramte et skib |
| `MISS B2` | Skuddet missede |
| `SUNK B2 Destroyer` | Skuddet sænkede Destroyer |
| `WIN` | Modstanderen har ingen skibe tilbage |

Eleverne kan øve sig ved at skrive beskederne direkte i `ncat` (f.eks. `echo "FIRE B2" | ncat ...`).
