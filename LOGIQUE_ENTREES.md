# Spécification cible des entrées et sorties

- Date de mise à jour : 9 août 2026
- Révision de référence : `9178b72`
- Composants concernés : `ICT_SilverBullet_Strategy.mq5` et `ICT_SilverBullet_Signals.mq5`
- Statut : logique fonctionnelle souhaitée, pas encore entièrement implémentée dans le code

## 1. Règles générales

La stratégie recherche une continuation après une prise de liquidité, une confirmation structurelle et un retracement dans la bonne moitié du dealing range.

```text
Biais D1 et stacking complets
    ↓
Purge de la liquidité opposée au futur trade
    ↓
Balayage/cassure du swing dans le sens du futur trade
    ↓
Déplacement + MSS + FVG directionnelle
    ↓
Construction du dealing range et de sa zone discount/premium
    ↓
Retracement dans cette zone pendant une Killzone ou une Macro
    ↓
Déclencheur FVG, OTE ou retest EMA
    ↓
Entrée
```

Principes obligatoires :

- toutes les décisions sont prises à partir de bougies clôturées ;
- les événements doivent respecter leur ordre chronologique ;
- un MSS antérieur à la purge ne peut pas valider le setup ;
- une ancienne liquidité déjà consommée ne peut pas recréer indéfiniment le même setup ;
- aucun stack complet signifie aucun trade et aucun signal ;
- le retracement final doit réellement entrer dans la zone autorisée ;
- l'entrée doit se produire pendant une fenêtre horaire autorisée.

## 2. Biais directionnel et stacking

### 2.1 Biais haussier

Le biais devient haussier uniquement lorsque la dernière bougie D1 clôturée respecte :

```text
Close D1 > EMA10 D1 > EMA20 D1
```

Le stacking de confirmation doit également être complètement aligné dans le sens haussier sur les timeframes de confirmation retenus.

### 2.2 Biais baissier

Le biais devient baissier uniquement lorsque la dernière bougie D1 clôturée respecte :

```text
Close D1 < EMA10 D1 < EMA20 D1
```

Le stacking de confirmation doit également être complètement aligné dans le sens baissier sur les timeframes de confirmation retenus.

### 2.3 Absence de stack

Si le D1 ou l'un des timeframes obligatoires ne possède pas un stack complet :

```text
Biais = NEUTRE
Trade = INTERDIT
Signal = INTERDIT
```

Le système ne doit pas conserver un ancien biais haussier ou baissier pendant une configuration EMA neutre.

Interprétation retenue pour le document :

- D1 définit le biais directeur ;
- H1, M5 et M1 restent les confirmations de stacking prévues par la solution actuelle ;
- si l'un de ces timeframes doit devenir facultatif, cela devra être défini explicitement dans les inputs.

## 3. Préparation d'un achat

Un setup LONG n'est valide que si les événements suivants apparaissent dans cet ordre.

### Étape 1 — Biais haussier complet

- `Close D1 > EMA10 D1 > EMA20 D1` ;
- stacking haussier complet sur les timeframes de confirmation ;
- direction LONG autorisée ;
- verrou journalier inactif ;
- limite de setups et de positions non atteinte.

### Étape 2 — Verrouillage des swings de référence

Le système identifie et mémorise :

- un swing low de référence ;
- un swing high de référence ;
- leurs timestamps et leurs prix.

Ces références ne doivent pas être remplacées au milieu de la séquence.

### Étape 3 — Purge du swing low

Le prix doit d'abord prendre la liquidité située sous le swing low de référence :

```text
Low < Swing Low de référence
```

Ce point bas purgé devient l'origine de la jambe haussière et le point Fibonacci `0`.

La purge du swing low doit obligatoirement précéder le balayage ou la cassure du swing high.

### Étape 4 — Balayage du swing high et MSS haussier

Après la purge du swing low, le prix doit dépasser l'ancien swing high :

```text
High de la bougie fermée > Swing High de référence
```

La confirmation structurelle haussière exige un MSS formé après la purge. La règle de confirmation recommandée est :

```text
Close de la bougie fermée > niveau structurel du swing high
```

Un simple ancien `g_mssBias` haussier ne doit pas suffire.

### Étape 5 — Déplacement haussier et création d'une FVG

La cassure doit produire :

- un déplacement haussier mesurable ;
- une FVG haussière créée après la purge ;
- une FVG orientée dans le sens de la jambe ;
- une zone exploitable située dans la partie discount du dealing range.

La FVG est un contexte obligatoire du setup, même si le déclencheur final retenu est un OTE ou un retest EMA.

### Étape 6 — Construction du dealing range

Pour un LONG :

- Fibonacci `0` = point bas de la purge du swing low ;
- Fibonacci `1` = point haut atteint par la jambe de déplacement ;
- équilibre `EQ` = 50 % du range ;
- discount = moitié basse, entre Fibonacci `0` et `EQ`.

```text
Range = Fib1 - Fib0
EQ = Fib0 + 0,50 × Range
Discount = [Fib0 ; EQ]
```

Le terminus Fibonacci `1` ne doit être figé qu'une fois la jambe de déplacement définie.

### Étape 7 — Retracement en discount

Après la création de la jambe, le prix doit retracer dans la zone discount.

L'entrée peut utiliser :

- une FVG haussière située en discount ;
- une zone OTE comprise dans la partie discount ;
- un retest EMA situé lui aussi en discount.

Un contact avec l'EMA en premium ne constitue pas une entrée LONG valide.

### Étape 8 — Filtre horaire

Le retracement et le déclenchement final doivent survenir pendant une Killzone ou une Macro autorisée. La formation initiale du setup peut avoir commencé avant la fenêtre, mais aucune entrée ne doit être produite hors fenêtre.

### Étape 9 — Déclenchement de l'achat

L'achat devient autorisé seulement lorsque toutes les conditions précédentes sont encore valides et que le prix a réellement traité la zone d'entrée.

```text
Biais haussier complet
AND purge du swing low
AND prise du swing high après la purge
AND déplacement haussier
AND MSS haussier postérieur à la purge
AND FVG haussière en discount
AND retracement en discount
AND Killzone ou Macro active
AND filtre de risque valide
= LONG autorisé
```

## 4. Préparation d'une vente

La logique SHORT est le miroir exact de la logique LONG.

### Étape 1 — Biais baissier complet

- `Close D1 < EMA10 D1 < EMA20 D1` ;
- stacking baissier complet sur les timeframes de confirmation ;
- direction SHORT autorisée ;
- limites de risque et de positions respectées.

### Étape 2 — Purge du swing high

Le prix doit d'abord prendre la liquidité située au-dessus du swing high de référence :

```text
High > Swing High de référence
```

Ce point haut devient l'origine de la jambe baissière et le point Fibonacci `0`.

### Étape 3 — Balayage du swing low et MSS baissier

Après la purge du swing high, le prix doit descendre sous le swing low de référence :

```text
Low de la bougie fermée < Swing Low de référence
```

Le MSS baissier doit être nouveau et postérieur à la purge. La confirmation recommandée est :

```text
Close de la bougie fermée < niveau structurel du swing low
```

### Étape 4 — Déplacement baissier et création d'une FVG

La cassure doit produire :

- un déplacement baissier mesurable ;
- une FVG baissière créée après la purge ;
- des bornes FVG correctement ordonnées ;
- une zone exploitable dans la partie premium du dealing range.

### Étape 5 — Construction du dealing range

Pour un SHORT :

- Fibonacci `0` = point haut de la purge du swing high ;
- Fibonacci `1` = point bas atteint par la jambe de déplacement ;
- équilibre `EQ` = milieu du range ;
- premium = moitié haute des prix, entre `EQ` et le point haut Fibonacci `0`.

```text
Range = Fib0 - Fib1
EQ = Fib1 + 0,50 × Range
Premium = [EQ ; Fib0]
```

### Étape 6 — Retracement en premium

L'entrée SHORT peut utiliser :

- une FVG baissière située en premium ;
- une zone OTE située en premium ;
- un retest EMA situé en premium.

Un contact avec l'EMA en discount ne constitue pas une entrée SHORT valide.

### Étape 7 — Déclenchement de la vente

```text
Biais baissier complet
AND purge du swing high
AND prise du swing low après la purge
AND déplacement baissier
AND MSS baissier postérieur à la purge
AND FVG baissière en premium
AND retracement en premium
AND Killzone ou Macro active
AND filtre de risque valide
= SHORT autorisé
```

## 5. Règles Fibonacci, OTE et FVG

### 5.1 Point zéro

Le point Fibonacci `0` représente obligatoirement l'origine de la jambe de déplacement :

- LONG : point bas obtenu lors de la purge du swing low ;
- SHORT : point haut obtenu lors de la purge du swing high.

Ce point est verrouillé pendant toute la vie du setup.

### 5.2 Équilibre

Le niveau 50 % sépare le dealing range :

- LONG autorisé seulement sous ou au niveau de l'EQ ;
- SHORT autorisé seulement au-dessus ou au niveau de l'EQ.

### 5.3 OTE

Pour un LONG, l'OTE correspond à un retracement de 62 % à 79 % depuis le sommet de la jambe vers son origine :

```text
OTE Long = [Fib1 - 0,79 × Range ; Fib1 - 0,62 × Range]
```

Pour un SHORT, l'OTE correspond à un retracement de 62 % à 79 % depuis le bas de la jambe vers son origine :

```text
OTE Short = [Fib1 + 0,62 × Range ; Fib1 + 0,79 × Range]
```

Les deux bornes 62 % et 79 % doivent être réellement contrôlées.

### 5.4 FVG obligatoire

Une FVG valide doit :

1. être créée après la purge initiale ;
2. être produite par la jambe de déplacement ;
3. être orientée dans le sens du futur trade ;
4. se situer dans la moitié autorisée du dealing range ;
5. ne pas avoir été invalidée avant le retracement ;
6. être réellement touchée si elle sert de déclencheur d'entrée.

Pour éviter une interprétation ambiguë de « FVG dans la zone », la partie de FVG utilisée comme prix d'entrée doit être entièrement dans la moitié autorisée. Une FVG traversant l'EQ ne permet pas d'entrer dans sa portion interdite.

## 6. Filtre horaire

Toutes les heures suivantes sont exprimées en heure de New York et doivent utiliser le DST applicable à la date de la bougie.

### 6.1 Fenêtres Londres et New York

| Session | Killzone | Macro associée | Fenêtre d'entrée résultante |
|---|---:|---:|---:|
| Londres | 03:00–04:00 | 03:45–04:15 | 03:00–04:15 |
| New York AM | 10:00–11:00 | 10:45–11:15 | 10:00–11:15 |
| New York PM | 14:00–15:00 | 14:45–15:15 | 14:00–15:15 |

### 6.2 Fenêtres asiatiques

Les deux fenêtres supplémentaires sont :

- 19:00–21:00 New York ;
- 21:00–23:59 New York.

Elles couvrent la phase asiatique du soir jusqu'à la fin de la journée New York.

### 6.3 Règle d'admission

```text
Entrée autorisée =
03:00–04:15
OR 10:00–11:15
OR 14:00–15:15
OR 19:00–21:00
OR 21:00–23:59
```

La condition horaire s'applique au retracement et au déclenchement d'entrée, pas nécessairement à la purge initiale ou au déplacement.

## 7. Machine d'état attendue

La logique doit être implémentée comme une séquence d'états afin d'interdire les événements hors ordre.

```text
WAIT_STACK
    ↓ stack complet
WAIT_REFERENCE_SWINGS
    ↓ swings verrouillés
WAIT_LIQUIDITY_PURGE
    ↓ purge du swing opposé
WAIT_DIRECTIONAL_BREAK
    ↓ prise du swing dans le sens du trade
WAIT_DISPLACEMENT_MSS_FVG
    ↓ déplacement + nouveau MSS + FVG valide
WAIT_RETRACEMENT_WINDOW
    ↓ discount/premium + fenêtre autorisée
READY_TO_ENTER
    ↓ ordre confirmé
POSITION_MANAGEMENT
```

Chaque setup doit mémoriser au minimum :

- direction ;
- prix et heure des swings de référence ;
- prix et heure de la purge ;
- origine Fibonacci `0` ;
- terminus Fibonacci `1` ;
- niveau EQ ;
- prix et heure du MSS ;
- bornes et heure de la FVG ;
- état de consommation de la liquidité ;
- date d'expiration ;
- identifiant et ticket réel après exécution.

## 8. Invalidation d'un setup

Le setup doit être annulé lorsque :

- le stacking complet disparaît ;
- le biais D1 devient neutre ou opposé ;
- le prix invalide l'origine Fibonacci `0` selon la règle de clôture retenue ;
- le MSS apparaît avant la purge ou dans le mauvais sens ;
- la FVG obligatoire est invalidée ;
- le terminus ou les swings de référence sont remplacés de manière incohérente ;
- la liquidité du setup a déjà été consommée ;
- le setup dépasse sa durée de vie maximale ;
- les limites journalières ou d'exposition interdisent l'entrée.

La fermeture d'une fenêtre horaire interdit l'entrée. La conservation éventuelle du setup jusqu'à une fenêtre suivante devra être définie explicitement avant l'implémentation.

## 9. Déclenchement et prix d'exécution

La logique fonctionnelle impose que le prix ait réellement traité la zone FVG, OTE ou EMA autorisée.

Deux modes d'exécution restent possibles :

1. ordre limite placé dans la zone ;
2. ordre au marché après une bougie de confirmation clôturée dans la zone.

Le mode doit devenir un input explicite. Dans les deux cas :

- le volume doit être calculé depuis le prix réellement exécutable ;
- le fill réel doit être contrôlé ;
- SL, R, TP1 et objectifs doivent être calculés ou réconciliés depuis le fill ;
- aucun prix théorique non traité ne doit être enregistré comme prix d'entrée.

## 10. Logique de sortie provisoire

La modification reçue définit précisément les entrées, mais ne change pas explicitement les règles de sortie. Jusqu'à confirmation contraire, la sortie cible reste provisoirement :

- SL structurel au-delà de l'origine Fibonacci `0`, avec buffer ;
- sortie partielle à TP1 ;
- passage du reliquat à break-even après TP1 confirmé ;
- runner vers le TP final ou trailing ;
- fermeture et verrouillage selon les limites de risque journalières.

Les valeurs actuellement documentées pour DE30/XAUUSD sont :

- TP1 : 2,5 R ;
- TP1 partiel : 30 % ;
- objectif final : 6 R ;
- trailing runner : 2,5 R.

Ces paramètres ne sont pas considérés comme définitivement validés par la présente spécification. La gestion de sortie doit fonctionner à chaque tick ou être protégée par des ordres broker, et non attendre la bougie suivante.

## 11. Différences avec le code actuel

| Sujet | Code actuel | Logique cible |
|---|---|---|
| Biais neutre | Conserve souvent le biais précédent | Aucun stack complet = aucun trade/signal |
| Départ LONG | Crée le setup après prise du swing high | Purge d'abord le swing low, puis prise du swing high |
| Départ SHORT | Crée le setup après prise du swing low | Purge d'abord le swing high, puis prise du swing low |
| Chronologie MSS | Peut réutiliser un état MSS antérieur | MSS nouveau, horodaté après la purge |
| FVG | Peut seulement servir d'armement/déclencheur | FVG directionnelle obligatoire dans la bonne moitié |
| Retest EMA | Ne contrôle pas discount/premium | EMA valide seulement dans discount/premium |
| OTE | Borne 79 % non appliquée | Zone complète 62–79 % obligatoire |
| Fenêtres | Londres/NY seulement | Londres, NY et deux fenêtres asiatiques |
| Fibonacci | Origine et terminus évolutifs selon le setup | Fib 0 verrouillé à la purge, Fib 1 au terminus |
| Liquidité consommée | Peut être réutilisée | Consommation persistante par niveau/setup |
| Exécution | Ordre marché au tick suivant depuis un prix théorique | Zone réellement traitée et fill réconcilié |
| Sorties | TP1/BE/trailing seulement à la nouvelle bougie | Gestion intrabar ou protections broker |

Le code ne doit donc pas être présenté comme conforme à cette spécification avant sa modification et sa validation.

## 12. Critères d'acceptation

### Scénario LONG valide

```text
Stack D1/confirmations haussier
→ swing low purgé
→ swing high pris après la purge
→ déplacement haussier
→ MSS haussier nouveau
→ FVG haussière en discount
→ retracement en discount pendant une fenêtre autorisée
→ déclencheur valide
→ achat
```

### Scénario SHORT valide

```text
Stack D1/confirmations baissier
→ swing high purgé
→ swing low pris après la purge
→ déplacement baissier
→ MSS baissier nouveau
→ FVG baissière en premium
→ retracement en premium pendant une fenêtre autorisée
→ déclencheur valide
→ vente
```

### Scénarios obligatoirement rejetés

- D1 ou confirmation sans stack complet ;
- sweep high pour un LONG sans purge préalable du swing low ;
- sweep low pour un SHORT sans purge préalable du swing high ;
- MSS antérieur à la purge ;
- FVG située dans la mauvaise moitié du range ;
- retest EMA hors discount/premium ;
- OTE au-delà de 79 % ou avant 62 % ;
- retracement hors Killzone/Macro ;
- réutilisation d'une liquidité déjà consommée ;
- entrée calculée sur un prix que le marché n'a jamais traité ;
- dépassement des limites de risque ou de positions.

## 13. Points restant à confirmer

La logique fournie permet de définir clairement la direction et la chronologie. Les décisions suivantes restent à fixer avant une implémentation sans ambiguïté :

1. le stacking complet exige-t-il obligatoirement D1 + H1 + M5 + M1, ou seulement D1 avec certaines confirmations facultatives ? (exige obligatoirement D1+H1+M5+M1)
2. la purge doit-elle être validée par un simple dépassement de mèche ou par une clôture de réintégration ? (Par une cloture)
3. le MSS doit-il casser le swing high/low de référence ou une structure interne formée après la purge ? (Le MSS doit casser le SH/SL d'une structure interne formee apres la purge)
4. une FVG est-elle valide lorsque seule sa Consequent Encroachment est en discount/premium, ou toute la zone doit-elle y être contenue ? (Oui ce FVG est valide)
5. l'entrée finale doit-elle être une limite dans la zone ou un marché après confirmation ? (L'entree doit etre au marche)
6. un setup formé hors fenêtre reste-t-il valide pour la prochaine Killzone/Macro ? (Non les conditions doivent etre respectees)
7. les deux fenêtres asiatiques doivent-elles être séparées fonctionnellement ou traitées comme une plage continue 19:00–23:59 ? ( elles doivent etre separees)
8. les règles de sortie provisoires doivent-elles être conservées telles quelles ? ( qu'est ce que tu me conseille?)

Ces points n'empêchent pas de comprendre la logique générale, mais ils doivent être tranchés avant de modifier le moteur de trading.

## Conclusion

La logique cible est comprise comme suit :

- **LONG** : biais et stacking haussiers, purge préalable du swing low, prise du swing high, déplacement, nouveau MSS, FVG haussière en discount, puis retracement en discount pendant une Killzone ou Macro ;
- **SHORT** : biais et stacking baissiers, purge préalable du swing high, prise du swing low, déplacement, nouveau MSS, FVG baissière en premium, puis retracement en premium pendant une fenêtre autorisée ;
- **aucun stack complet** : aucun trade et aucun signal ;
- **Fibonacci 0** : origine verrouillée au point de purge ;
- **horaires autorisés** :  
* Asian killzone: 07:00 PM - 10:00 PM
 * London killzone: 02:00 AM - 05:00 AM
 * New York killzone: 07:00 AM - 10:00 AM
en heure de New York.
