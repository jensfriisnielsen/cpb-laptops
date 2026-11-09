# Python-kryptering af beskeder

Som I har set på de foregående sider, sender `ncat` alt i **klartekst** — enhver, der
kan lytte med på forbindelsen, kan læse beskeden. Før vi ser på rigtig kryptering med
`ncat --ssl` (på [næste side](avanceret.md)), skal I selv skrive programmer, der
krypterer en besked, **inden** den sendes over `ncat`.

Det danske alfabet har **29 bogstaver** — a-z samt æ, ø, å — og Cæsar- og
substitutions-ciferet nedenfor bruger alle 29, så æ, ø og å er lige så krypterede
som resten af beskeden.

Scripts herunder er installeret globalt på laptopperne (som pakken `krypt-opgave`,
se [`modules/krypt-opgave.nix`](../../../../../../modules/krypt-opgave.nix)), så I kan
køre dem direkte som `krypt-caesar`, `krypt-bogstavbytte` og `krypt-rsa` — uden
`python3` foran og uden at skulle finde scriptet på disken.

## Cæsar-kryptering (det enkleste cifer)

Den romerske feltherre Julius Cæsar krypterede sine beskeder ved at flytte hvert
bogstav et fast antal pladser i alfabetet — fx bliver `a` til `d`, `b` til `e` osv.,
hvis man flytter 3 pladser. Her er et lille program, der gør det:

```python
{{#include scripts/kryptering/caesar.py}}
```

Prøv det alene først:

```sh
krypt-caesar -f 7 "Hemmelig besked, æøå"
krypt-caesar -f 7 -d "Olttlspn ilzrlk, efg"
```

Brug det derefter sammen med `ncat`. Afsender og modtager skal være enige om nøglen
(tallet efter `-f`) på forhånd — det er den, der holder beskeden hemmelig.

På **afsenderen**:

```sh
krypt-caesar -f 7 "Mød mig kl 15 ved porten" \
  | ncat --send-only 100.101.102.103 5002
```

På **modtageren**:

```sh
ncat -l --recv-only 5002 | krypt-caesar -f 7 -d
```

En Cæsar-nøgle er bare et tal mellem 1 og 28 — der er kun **28 mulige nøgler** at
gætte (det danske alfabet har 29 bogstaver, så der er 29 mulige flytninger, men at
flytte 0 pladser krypterer jo ikke noget), så en modstander kan prøve dem alle på
et øjeblik.

## Dit eget cifer: byt bogstaver ud, som du vil

I stedet for at flytte alfabetet et fast antal pladser, kan I selv bestemme, hvilket
bogstav hvert bogstav skal blive til — en **substitutionskryptering**. Cæsar-kryptering
er faktisk bare et specialtilfælde af dette, hvor nøglen er "alfabetet flyttet N
pladser".

```python
{{#include scripts/kryptering/bogstavbytte.py}}
```

Nøglen er en blanding af alle 29 bogstaver i det danske alfabet (a-z samt æ, ø, å),
fx `qwertyuiopåasdfghjklæøzxcvbnm` (det danske tastatur, række for række — øverste
række ender på `å`, midterste på `æø`). Brug den samme opskrift som før:

```sh
# Afsender
krypt-bogstavbytte -n "qwertyuiopåasdfghjklæøzxcvbnm" \
  "Mød mig kl 15 ved porten" | ncat --send-only 100.101.102.103 5002
```

```sh
# Modtager
ncat -l --recv-only 5002 \
  | krypt-bogstavbytte -n "qwertyuiopåasdfghjklæøzxcvbnm" -d
```

Der er **29! (29 fakultet)** — over 8,8 kvintillioner (8,8 × 10^30) — mulige nøgler,
så det kan ikke gættes ved at prøve alle sammen. Alligevel er sådan et cifer ikke
sikkert i praksis: nogle bogstaver (som `e` og `t`) optræder meget oftere end andre
på dansk — mens æ, ø og å er forholdsvis sjældne — så en modstander kan gætte
nøglen ved at tælle, hvilke tegn der går igen oftest (frekvensanalyse).

## "Stærk" kryptering med to primtal (mini-RSA)

Rigtig moderne kryptering (som den `ncat --ssl` bruger på næste side) er bygget på
matematik i stedet for at gætte bogstaver. Et kendt eksempel er **RSA**: man vælger to
primtal, ganger dem sammen, og bruger resultatet til at lave en **offentlig nøgle**
(som alle må kende, og som bruges til at kryptere) og en **hemmelig nøgle** (som kun
modtageren kender, og som bruges til at dekryptere).

```python
{{#include scripts/kryptering/rsa_lille.py}}
```

Beskeden krypteres byte for byte (UTF-8), så æ, ø og å virker uden videre — de
fylder bare to bytes hver i stedet for én.

Her er nogle primtal, I kan bruge (vælg to forskellige): `11, 13, 17, 19, 23, 29, 31,
37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97`.

Lav et nøglepar:

```sh
krypt-rsa noegler --p 61 --q 53
```

Det giver jer `n`, `e` (den offentlige nøgle) og `d` (den hemmelige nøgle) — med
`--p 61 --q 53` bliver det `n=3233`, `e=7` og `d=1783`. Krypter og send en besked
(brug jeres egne `n`, `e` og `d`, hvis I valgte andre primtal):

```sh
# Afsender — kryptér med den offentlige nøgle (n, e)
krypt-rsa krypter --n 3233 --e 7 \
  "Mød mig kl 15 ved porten" | ncat --send-only 100.101.102.103 5003
```

```sh
# Modtager — dekryptér med den hemmelige nøgle (n, d)
ncat -l --recv-only 5003 \
  | krypt-rsa dekrypter --n 3233 --d 1783
```

Nu til pointen: prøv at "angribe" jeres egen besked, kun ud fra den offentlige nøgle
(`n` og `e`) og den krypterede tekst, I sendte over `ncat`:

```sh
krypt-rsa knaek --n 3233 --e 7 \
  --kryptotekst "3004,2909,62,2872,2774,597,3020,728,..."
```

Det går hurtigt, fordi `n` kun er produktet af to små primtal — computeren kan prøve
sig frem til dem begge på et øjeblik. Rigtig RSA bruger primtal med **flere hundrede
cifre**. Samme fremgangsmåde ville der tage længere end universets levetid, og det er
hele forskellen mellem en "leget" og en rigtig sikker nøgle.

## Opgaver til eleverne

1. **Gæt nøglen:** Bed en makker kryptere en kort besked med `krypt-caesar` uden at
   fortælle dig nøglen. Hvor lang tid tager det dig at gætte den (husk: der er kun 28
   muligheder)?
2. **Dit eget cifer:** Opfind jeres egen 29-bogstavers nøgle til `krypt-bogstavbytte`
   (husk æ, ø og å), og send en krypteret besked over `ncat`. Hvorfor er dette cifer
   svagt, selvom der er 29! mulige nøgler?
3. **Knæk jeres egen RSA:** Lav et nøglepar med `krypt-rsa noegler`, kryptér en
   besked, og "angrib" den bagefter med `knaek` — kun ud fra den offentlige nøgle (n,
   e). Hvad ville der ske med `knaek`-kommandoens kørselstid, hvis p og q havde 150
   cifre i stedet for 2-3?

Næste side: [Avanceret ncat: SSL og ARP-spoofing](avanceret.md).
