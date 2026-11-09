# Netværk og ncat: det grundlæggende

Dette kapitel handler om, hvordan to laptops kan tale sammen over skolens **Netbird**-
netværk med programmet **ncat**. Kapitlet har fire sider: dette grundlæggende afsnit,
derefter [Manden-i-midten](manden-i-midten.md),
[Python-kryptering af beskeder](python-kryptering.md) og til sidst
[Avanceret ncat: SSL og ARP-spoofing](avanceret.md).

## Hvad er ncat?

`ncat` er et lille værktøj til at sende og modtage data over netværk. Det er en del af
programmet **nmap**, som allerede ligger på din laptop. Du åbner **Terminal** og skriver
kommandoerne derfra.

`ncat` kan:

- lytte på en port og vente på forbindelser (`-l`),
- forbinde til en anden computer,
- sende tekst, filer og endda køre programmer,
- bruge TCP, UDP og TLS.

## Find din Netbird-adresse

Netbird giver hver laptop en fast IP-adresse i `100.64.0.0/10`-området. Alle i jeres
Netbird-netværk kan nå hinanden på disse adresser, også selv om I sidder i forskellige
lokaler.

```sh
# Er Netbird oppe? Viser status, netværksnavn og egne adresser.
netbird status

# Mere detaljeret: alle peers (de andre laptops) og deres IP-adresser.
netbird status --detail

# Netbird bruger et WireGuard-interface. Det hedder normalt wt0.
ip -brief addr show wt0
```

Skriv din egen adresse op (fx `100.101.102.103`) og giv den til makkeren, I skal tale
med. De skal gøre det samme.

Hvis Netbird ikke er forbundet:

```sh
netbird up
netbird status
```

## Forbind to laptops med ncat

Vi kalder den ene laptop for **serveren** (den der lytter) og den anden for
**klienten** (den der forbinder). Vælg et portnummer over 1024, fx **5000**.

### 1. Enkel chat (én besked hver vej)

På **serveren**:

```sh
ncat -l 5000
```

På **klienten** (indsæt serverens Netbird-adresse):

```sh
ncat 100.101.102.103 5000
```

Nu kan I skrive til hinanden. Linjerne, du skriver, dukker op hos den anden, når du
trykker **Enter**. Afslut med **Ctrl+D** (eller **Ctrl+C**).

### 2. Bliv ved med at lytte

Med standard-`ncat` lukker serveren, så snart klienten går. Det undgår du sådan:

```sh
ncat -l --keep-open 5000
```

Nu kan flere klienter forbinde efter hinanden.

### 3. Test på din egen maskine

Før I prøver mellem to laptops, kan du teste, om `ncat` virker lokalt. Åbn **to**
terminal-vinduer:

```sh
# Terminal 1
ncat -l 5000
```

```sh
# Terminal 2
ncat 127.0.0.1 5000
```

Skriv noget i terminal 2 — det dukker op i terminal 1.

## Send filer

`ncat` kan sende alle slags data, ikke kun tekst. Igen: serveren lytter, klienten
sender.

På **modtageren**:

```sh
ncat -l 5000 > modtaget.bin
```

På **afsenderen**:

```sh
ncat 100.101.102.103 5000 < billede.png
```

Afslut med **Ctrl+D**, når filen er sendt. Tjek bagefter, at filerne har samme
størrelse:

```sh
ls -l billede.png modtaget.bin
```

Man kan også bruge `--send-only` og `--recv-only`, så `ncat` lukker af sig selv, når
data er sendt:

```sh
# Modtager
ncat -l --recv-only 5000 > modtaget.bin
```

```sh
# Afsender
ncat --send-only 100.101.102.103 5000 < billede.png
```

## Fejlfinding

| Problem | Løsning |
| --- | --- |
| `Ncat: Connection refused` | Serveren lytter ikke. Tjek, at `ncat -l` kører på den anden maskine, og at portnummeret er det samme. |
| `Ncat: No route to host` | Netbird er ikke oppe, eller adressen er forkert. Kør `netbird status` på begge maskiner. |
| `Ncat: Address already in use` | Porten er optaget. Se hvem der bruger den, eller vælg en anden port. |
| Intet sker | Firewall? Tjek `sudo ss -tlnp | grep 5000` for at se, om nogen lytter. |
| Virker lokalt, men ikke mellem laptops | Skriv `ip -brief addr show wt0` og brug **wt0**-adressen — ikke Wi-Fi-adressen. |

```sh
# Hvilke porte lytter din maskine på lige nu?
ss -tlnp

# Kan du overhovedet nå den anden laptop?
ping 100.101.102.103
```

## Opgaver til eleverne

1. **Chat:** Få en `ncat`-chat til at virke mellem to laptops over Netbird. Hvilken
   adresse brugte I, og hvorfor ikke Wi-Fi-adressen?
2. **Filoverførsel:** Send et billede fra den ene laptop til den anden. Tjek, at
   filerne er **bit for bit** ens (brug fx `sha256sum` på begge).

Næste side: [Manden-i-midten](manden-i-midten.md).
