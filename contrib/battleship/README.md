# 🚢 Sænke Slagskibe – TUI-netværksspil

Et simpelt undervisningsprojekt hvor elever placerer skibe via en konfigurationsfil (eller tilfældigt layout) og derefter skyder på hinanden over netværket ved hjælp af **indbygget TCP**.

## Koncept

- Spillet har en **indbygget TCP-server** (lyt på en port) eller fungere som **klient**.
- Intet behov for fifos eller eksterne ncat-kommandoer – alt er indbygget.
- **TUI** med to rækker:
  1. `[Modstanderens bræt | Dit bræt]`
  2. `[Felt til at skyde | Seneste svar du gav modstanderen]`
- Klienten (den der forbinder) starter med at skyde.
- Boksen **Seneste svar** viser det seneste svar *du* gav til modstanderens skud
  (`HIT`/`MISS`/`SUNK`/`INVALID`), altså under dit eget bræt.
- Rå netværkstrafik kan ses med `--debug` i TUI'en eller logges til en fil med `--log`.

## Installation

```bash
# Kør direkte fra repoet
nix run .#slagskibe -- --help
```

## Hurtig start

### Server (vent på modstander)

```bash
nix run .#slagskibe
```

Spillet viser en besked som `Venter på modstander: ncat [IP_ADDRESS] 4000`.
Giv denne besked til din modstander.

### Klient (forbind til server)

```bash
nix run .#slagskibe -- [IP_ADDRESS]:4000
```

### Tilfældigt layout

Udelad `--config` for at få et tilfældigt gyldigt skibslayout:

```bash
nix run .#slagskibe
```

### Brugerdefineret layout

```bash
nix run .#slagskibe -- --config ships.yaml
```

### Debug-tilstand (i TUI'en)

```bash
nix run .#slagskibe -- --debug
# tryk 'l' for at vise/skjule logpanelet
```

### Lyt med udefra (traffiklog)

```bash
nix run .#slagskibe -- --log /tmp/slagskibe.log
# i en anden terminal:
tail -f /tmp/slagskibe.log
```

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

## TUI taster

Indtastningsfeltet har fokus, så almindelige bogstaver går til koordinatet.
Kontroltaster gives derfor med `:` som prefiks (som i vim):

| Kommando | Funktion          |
|----------|-------------------|
| `:?`     | Vis hjælp         |
| `:l`     | Vis/skjul log     |
| `:q`     | Afslut spil       |
| Escape   | Luk hjælp / annuller `:` |

## Protokol

Al kommunikation sker i **ren tekst** linje for linje:

| Besked | Beskrivelse |
|--------|-------------|
| `FIRE B2` | Affyr et skud på B2 |
| `HIT B2` | Skuddet ramte et skib |
| `MISS B2` | Skuddet missede |
| `SUNK B2 Destroyer` | Skuddet sænkede Destroyer |
| `WIN` | Modstanderen har ingen skibe tilbage |
| `INVALID ZZ INVALID_COLUMN` | Skuddet blev afvist; afsenderen må prøve igen |

Modtageren validerer alle `FIRE`-beskeder. Er koordinatet ugyldigt (f.eks. `ZZ`
og `K11`), svarer modtageren `INVALID` og turen går tilbage til afsenderen.

## Lytte på trafikken

Forbindelsen er **direkte peer-til-peer**. Serveren accepterer kun *én*
forbindelse, så du kan **ikke** bagefter sætte `ncat localhost 4000` ved siden af
— porten er allerede taget af spilklienten (derfor "Connection refused").

Brug i stedet en af disse:

1. **`--log FIL`** på begge maskiner — skriver hver linje med tidsstempel og
   retning (`>>` sendt, `<<` modtaget). Følg med via `tail -f FIL`.
2. **`--debug`** i TUI'en — viser rå trafik i logpanelet (tast `l`).
3. **`ncat` som selve klienten** — det virker fint mod en anden spillers server:
   ```bash
   ncat [IP_ADDRESS] 4000
   FIRE B2
   ```

### ncat som mellemled (proxy) med log

Vil du se trafikken med `ncat`, skal den stå *imellem* de to spillere. Lad
serveren lytte på 4000 og sæt en `ncat`-proxy op på 4010 der videresender til
4000, så klienten forbinder til 4010:

```bash
# på server-maskinen (spillet lytter på 4000):
ncat -l 4010 -k --sh-exec 'ncat localhost 4000' | tee -a /tmp/traffic.log
```

> `ncat` er en simpel tovejs-proxy og er ikke ideel til at logge begge
> retninger pænt. Vil du have begge retninger med, brug `--log` (anbefales) eller
> `socat -v TCP-LISTEN:4010,reuseaddr,fork TCP:localhost:4000`.

## Se også

- `nix run .#slagskibe -- --help` for alle kommandolinjeindstillinger
- `examples/ships.yaml` for eksempel på skibskonfiguration