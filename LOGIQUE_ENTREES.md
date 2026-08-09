# Logique des entrées achat et vente

- Date d'analyse : 9 août 2026
- Révision étudiée : `9178b72`
- EA automatique concerné : `ICT_SilverBullet_Strategy.mq5`
- Magic number : `260711`

## Résumé

Dans le code actuel, seul `ICT_SilverBullet_Strategy.mq5` décide automatiquement d'acheter ou de vendre.

Il n'entre pas directement au moment du sweep. Il construit d'abord un setup, attend ses confirmations, puis envoie un ordre au marché au premier tick de la bougie suivante.

```text
Biais alignés
    ↓
Sweep d'une ancienne liquidité
    ↓
Déplacement ou FVG confirmant le setup
    ↓
MSS dans le même sens
    ↓
Déclencheur FVG, OTE ou retest EMA
    ↓
Ordre au marché à l'ouverture de la bougie suivante
```

La logique principale n'est exécutée qu'une fois par nouvelle bougie (`ICT_SilverBullet_Strategy.mq5:407-413`). Les prix analysés sont ceux de la bougie qui vient de clôturer (`:419-426`).

## 1. Filtre de direction

L'EA calcule quatre biais EMA10/EMA20 :

- biais principal H1 ;
- confirmation M5 ;
- confirmation M1 ;
- tendance de fond D1.

Un biais devient haussier lorsque :

```text
Close > EMA10 > EMA20
```

Un biais devient baissier lorsque :

```text
Close < EMA10 < EMA20
```

Si les EMA ne forment aucun stack complet, le code conserve le biais précédent (`ICT_SilverBullet_Strategy.mq5:244-253`).

Avec `InpRequireAlign=true`, les biais H1, M5 et M1 doivent être identiques (`:441-447`). Avec `InpUseTrendFilter=true`, le biais D1 doit également avoir la même direction (`:448-449`).

## 2. Préparation d'un achat

Un setup LONG est créé lorsque toutes les conditions suivantes sont remplies :

1. le biais aligné est haussier ;
2. les derniers swings high et low ont été détectés ;
3. la direction LONG est autorisée ;
4. le verrou journalier n'est pas actif ;
5. la limite de setups et positions n'est pas atteinte ;
6. le high de la bougie fermée dépasse un ancien swing high ;
7. ce swing n'est pas déjà présent dans les setups actifs.

Condition centrale :

```mql5
if(h1 > g_lastSwingHi && !AlreadySwept(g_lastSwingHi, 1))
   CreateSetup(1, g_lastSwingHi, g_lastSwingLo, g_lastSwingLo, h1);
```

Référence : `ICT_SilverBullet_Strategy.mq5:602-614`.

Le LONG utilise donc une logique de continuation particulière : il est préparé après la purge d'un ancien swing **high**, et non après la purge d'un swing low.

## 3. Préparation d'une vente

Un setup SHORT est créé lorsque :

1. le biais aligné est baissier ;
2. les derniers swings high et low sont disponibles ;
3. la direction SHORT est autorisée ;
4. le compte n'est pas verrouillé pour la journée ;
5. les limites de positions/setups l'autorisent ;
6. le low de la bougie fermée descend sous un ancien swing low ;
7. ce swing n'est pas déjà présent dans les setups actifs.

Condition centrale :

```mql5
if(l1 < g_lastSwingLo && !AlreadySwept(g_lastSwingLo, -1))
   CreateSetup(-1, g_lastSwingLo, g_lastSwingHi, l1, g_lastSwingHi);
```

Référence : `ICT_SilverBullet_Strategy.mq5:615-620`.

Le SHORT est donc préparé après la purge d'un ancien swing **low**.

## 4. Armement du setup

Après sa création, le setup ne peut pas encore entrer immédiatement.

Il devient armé lorsqu'au moins une des conditions suivantes apparaît :

- une FVG est détectée dans le sens de la jambe ;
- le déplacement depuis l'origine atteint `InpMinDispTicks`, soit 20 ticks par défaut.

Référence : `ICT_SilverBullet_Strategy.mq5:478-490`.

Le setup est supprimé si :

- le prix clôture au-delà de son origine structurelle dans le mauvais sens ;
- l'alignement des biais est perdu ;
- son âge dépasse `InpSetupExpiry`, soit 30 bougies par défaut.

Référence : `ICT_SilverBullet_Strategy.mq5:492-496`.

## 5. Confirmation MSS

Avec `InpRequireMSS=true`, un MSS récent doit confirmer la direction :

### MSS haussier

```text
Close de la bougie fermée > dernier swing high
```

### MSS baissier

```text
Close de la bougie fermée < dernier swing low
```

Le MSS doit se situer dans les `InpMssLookback` dernières bougies, soit 15 par défaut (`ICT_SilverBullet_Strategy.mq5:451-455`, `:501`).

## 6. Filtre horaire

Si `InpUseSbWindows=true`, l'entrée doit être évaluée dans l'une des fenêtres New York suivantes :

- 03:00–04:00, prolongée par la macro jusqu'à 04:15 ;
- 10:00–11:00, prolongée jusqu'à 11:15 ;
- 14:00–15:00, prolongée jusqu'à 15:15.

Référence : `ICT_SilverBullet_Strategy.mq5:205-215`.

Les presets DE30 et XAUUSD activent ce filtre. L'audit a cependant identifié une conversion horaire à corriger dans le Strategy Tester.

## 7. Déclencheurs d'entrée

Le code teste les modèles dans cet ordre :

1. FVG ;
2. OTE ;
3. retest EMA.

Le premier modèle valide déclenche l'entrée. Les autres ne sont alors plus évalués pour cette bougie (`ICT_SilverBullet_Strategy.mq5:498-544`).

### 7.1 Entrée FVG

Pour un LONG, la bougie doit intersecter la FVG haussière située dans la moitié discount de la jambe.

Pour un SHORT, la bougie doit satisfaire la condition FVG baissière dans la moitié premium.

Référence : `ICT_SilverBullet_Strategy.mq5:508-515`.

Le contre-audit relève toutefois une inversion des bornes de la FVG baissière. Ce modèle est désactivé dans les presets DE30 et XAUUSD.

### 7.2 Entrée OTE

Pour un LONG :

- le low doit atteindre au moins le niveau de retracement 62 % ;
- le prix théorique est ensuite construit autour du sweet spot 70,5 %.

Pour un SHORT :

- le high doit atteindre au moins le niveau 62 % ;
- le prix théorique est construit autour du sweet spot 70,5 %.

Référence : `ICT_SilverBullet_Strategy.mq5:516-534`.

Ce modèle est désactivé dans les presets DE30 et XAUUSD. La borne `InpOteHigh=0.79` n'est pas réellement vérifiée par le code actuel.

### 7.3 Entrée sur retest EMA

C'est le seul modèle actif dans les presets DE30 et XAUUSD.

#### Achat EMA

La bougie fermée doit toucher ou traverser l'EMA rapide, puis clôturer haussière :

```mql5
low <= EMA10 && close >= open
```

Le prix théorique d'entrée est le close de cette bougie.

#### Vente EMA

La bougie fermée doit toucher ou traverser l'EMA rapide, puis clôturer baissière :

```mql5
high >= EMA10 && close <= open
```

Le prix théorique d'entrée est également son close.

Référence : `ICT_SilverBullet_Strategy.mq5:536-540`.

Le retest EMA ne vérifie pas que le prix se trouve réellement dans la moitié discount pour un achat ou premium pour une vente.

## 8. Moment exact du passage d'ordre

Lorsque toutes les conditions sont satisfaites, `EnterSetup()` est appelé (`ICT_SilverBullet_Strategy.mq5:543-544`).

L'ordre est envoyé ainsi :

```mql5
trade.Buy(total, _Symbol, 0.0, slN, tp4N, comment);
trade.Sell(total, _Symbol, 0.0, slN, tp4N, comment);
```

Référence : `ICT_SilverBullet_Strategy.mq5:358-364`.

La valeur `price=0.0` signifie que l'ordre est exécuté au marché :

- achat au prix Ask disponible ;
- vente au prix Bid disponible.

L'entrée réelle intervient donc au premier tick de la nouvelle bougie, et non exactement au close, au niveau OTE ou à la borne FVG calculée sur la bougie précédente.

Exemple sur un graphique M5 :

```text
10:20–10:24:59 : la bougie touche l'EMA et clôture avec les confirmations
10:25:00 environ : premier tick de la nouvelle bougie
                      → envoi immédiat de Buy ou Sell au marché
```

## 9. Conditions supplémentaires avant l'ordre

Même avec un signal valide, l'EA refuse l'entrée lorsque :

- `g_dayLocked=true` après la limite journalière interne ;
- `OpenTradeCount() >= InpMaxPositions` ;
- la direction est interdite par `InpTradeDir` ;
- le setup a expiré ou perdu son biais ;
- le MSS est absent ou trop ancien ;
- la fenêtre Silver Bullet est fermée lorsque le filtre est actif ;
- le calcul du risque, du SL ou du volume échoue.

## 10. Paramétrage DE30 et XAUUSD actuel

Les presets fournis utilisent principalement :

```text
OTE                  = OFF
FVG                  = OFF
Retest EMA           = ON
MSS obligatoire      = ON
Filtre tendance D1   = ON
Killzones NY         = ON
Direction            = achat et vente
```

La séquence réellement recherchée est donc :

### Achat avec les presets

```text
H1/M5/M1 haussiers + D1 haussier
→ dépassement d'un ancien swing high
→ déplacement confirmé
→ MSS haussier récent
→ bougie dans une fenêtre NY
→ low touche EMA10 et bougie clôture haussière
→ Buy au marché au premier tick suivant
```

### Vente avec les presets

```text
H1/M5/M1 baissiers + D1 baissier
→ passage sous un ancien swing low
→ déplacement confirmé
→ MSS baissier récent
→ bougie dans une fenêtre NY
→ high touche EMA10 et bougie clôture baissière
→ Sell au marché au premier tick suivant
```

Les presets ne fixent pas tous les inputs de l'EA. Cette description suppose donc les valeurs par défaut actuelles pour les paramètres absents.

## 11. Rôle des autres composants

### `ICT_SilverBullet_Signals.mq5`

L'indicateur reproduit globalement la même logique et dessine un signal LONG ou SHORT. Il ne passe aucun ordre.

### `TA_RiskManager.mq5`

Le Risk Manager ne prédit pas la direction du marché. Il passe un ordre uniquement après une action de l'utilisateur :

- `BUY` : achat immédiat au prix Ask ;
- `SELL` : vente immédiate au prix Bid ;
- `B.LMT` ou `S.LMT` : ordre en attente au prix saisi ; le code choisit automatiquement entre limit et stop selon la position du prix par rapport au marché.

Référence : `TA_RiskManager.mq5:344-428`.

### `ICT_TopDown_Confluence.mq5`

Cet indicateur affiche le contexte, la structure et les zones. Il ne passe aucun ordre.

## Conclusion

L'EA automatique cherche une continuation de tendance :

- **achat** après dépassement d'une ancienne liquidité haute, puis confirmation et retest ;
- **vente** après passage sous une ancienne liquidité basse, puis confirmation et retest.

Avec les presets actifs, le déclencheur final est un retest de l'EMA10 confirmé par la couleur de la bougie. L'ordre réel est ensuite envoyé au marché au premier tick de la bougie suivante.
