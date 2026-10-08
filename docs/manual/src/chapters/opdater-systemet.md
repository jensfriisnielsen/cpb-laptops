# Opdater systemet

Laptopen opdaterer sig selv hver dag omkring **kl. 17:30** — det sker helt automatisk,
og du behøver ikke gøre noget. Hvis du er i gang på computeren, når det sker, kan det
føles lidt langsomt et øjeblik.

## Opdater selv (nemmeste måde)

1. Klik på **Opdater system** i docken (ikonet med opdateringssymbolet).
2. Skriv **Admin**-adgangskoden (spørg din lærer, hvis du ikke har den).
3. Et vindue åbnes og viser opdateringen. Tryk **Enter**, når det siger, du kan lukke.

![Ikonet Opdater system i docken](../update-icon.png)

## Opdater selv (i terminalen)

Hvis du hellere vil, kan du skrive i **Terminal**:

```sh
sudo systemctl start nixos-upgrade.service
```

## Hvorfor opdatere?

Opdateringer giver dig nye programmer og retter fejl og huller i sikkerheden — så
computeren er hurtigere og mere sikker. **Du taber ikke dine egne filer, når du
opdaterer.**

Videre til [koderup.dk og hjemmesiden](koderup-dk.md).