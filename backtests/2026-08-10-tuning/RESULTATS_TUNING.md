# Tuning des entrées - DE30 et XAUUSD

- Date d'exécution : 10 août 2026
- Période : 2 janvier 2024 au 8 août 2026
- Modélisation MT5 : vrais ticks (`Model=4`)
- Timeframe d'exécution : M1
- Capital : 100 000 USD
- Levier : 1:100
- Serveur : Exness, base GMT+2 avec DST Europe
- Sorties conservées : TP1 2R, partiel 50 %, runner 4R, trailing 2R

## Résultat

| Symbole | Profil | Positions réellement ouvertes | `Total Trades` MT5 | Net | Profit factor | DD equity max | Sharpe |
|---|---|---:|---:|---:|---:|---:|---:|
| DE30 | ET0, prix exécutable strict dans la moitié | 1 | 2 | +1 322,49 USD | 80,096 | 1,54 % | 1,489 |
| DE30 | ET10, tolérance spread de 10 ticks autour de l'EQ | 2 | 3 | -462,89 USD | 0,589 | 2,47 % | -1,004 |
| XAUUSD | ET0, prix exécutable strict dans la moitié | 1 | 2 | +1 309,14 USD | 123,579 | 0,98 % | 2,311 |
| XAUUSD | ET10, tolérance spread de 10 ticks autour de l'EQ | 2 | 4 | +2 464,12 USD | 73,346 | 2,41 % | 2,871 |

`Total Trades` est la statistique native MT5. Une position Silver Bullet peut y
compter plusieurs trades à cause de la sortie partielle et du runner. Le nombre
de positions ci-dessus provient des entrées réelles journalisées par l'EA.

Ces résultats prouvent que le moteur peut désormais produire et exécuter des
ordres sur les deux marchés. Ils ne prouvent pas un avantage statistique : une
ou deux positions par symbole restent très insuffisantes pour valider la
rentabilité, le profit factor ou le Sharpe.

## Profil d'entrée testé

```text
Timeframe                    M1
Stack                        D1 + H1 + M5 + M1, EMA10/EMA20 strict
Déclencheurs                 FVG + OTE + EMA10
Pivot externe                1/1
Pivot interne                1/1
Cible avant pivot interne    autorisée et mémorisée
MSS avant cible              autorisé s'il est post-purge et causal
Rejet directionnel           facultatif
FVG candidates               4 maximum, CE toujours obligatoire
Expiration                   180 bougies, sans passage de fenêtre
Tolérance exécution EQ       0 ou 10 ticks selon le profil
```

La tolérance ET10 ne fabrique pas un prix d'entrée. L'ordre reste au marché et
le fill réel est réconcilié. Elle étend seulement la borne EQ de 10 ticks afin
de couvrir le spread entre la clôture Bid et l'Ask d'achat. Aucune tolérance
n'est appliquée du côté de Fibonacci 0. ET10 est donc un mode expérimental et
n'est pas strictement conforme à la règle « prix exécutable sous/sur EQ ».

## Funnel du profil ET10

| Étape | DE30 | XAUUSD |
|---|---:|---:|
| Setups créés | 352 | 639 |
| Pivots internes | 119 | 256 |
| Cibles externes | 142 | 280 |
| MSS confirmés | 56 | 91 |
| FVG de confirmation | 32 | 57 |
| Signaux finaux | 2 | 2 |
| Entrées confirmées | 2 | 2 |

Le verrou dominant reste le retracement final dans la même fenêtre New York.
Augmenter la capacité de 3 à 10 setups, abaisser le déplacement de 20 à 1 tick
ou conserver quatre FVG au lieu d'une n'a pas augmenté les signaux sur cet
échantillon. Le passage des swings externes de 2/2 à 1/1 est le réglage qui a eu
le plus d'effet sur la fréquence.

## Fichiers reproductibles

- `ict_sb_de30_m1_frequency.ini` et `ict_sb_xauusd_m1_frequency.ini` : ET10 ;
- `ict_sb_de30_m1_strict_spread.ini` et
  `ict_sb_xauusd_m1_strict_spread.ini` : ET0 ;
- `metrics_*_et0.csv` et `metrics_*_et10.csv` : sortie `OnTester()` ;
- rapports HTML et graphiques MT5 disponibles pour DE30 ET0/ET10 et XAUUSD
  ET10 ; le CSV `metrics_xauusd_et0.csv` reste la source reproductible du cas
  XAUUSD ET0, dont le rapport HTML n'a pas été exporté.

Presets à charger sur un graphique M1 :

- `ICT_SB_DE30_M1_RELAXED_ET0.set` / `ET10.set` ;
- `ICT_SB_XAUUSD_M1_RELAXED_ET0.set` / `ET10.set`.

## Décision prudente

- Pour vérifier que les ordres partent : utiliser ET10 en compte démo.
- Pour rester strict sur le prix exécutable : utiliser ET0.
- Ne pas déployer ces profils en réel sur la base de ces résultats.
- La prochaine validation doit couvrir plusieurs périodes IS/OOS, davantage
  d'années, les coûts réels, un walk-forward et un Monte-Carlo. Un minimum de
  plusieurs dizaines de positions indépendantes est nécessaire avant toute
  conclusion de performance.
