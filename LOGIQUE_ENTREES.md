# Spécification de référence des entrées et sorties

- Date de mise à jour : 10 août 2026
- Révision historique citée : `9178b72`
- Composants : `ICT_SilverBullet_Core.mqh`, `ICT_SilverBullet_Strategy.mq5` et `ICT_SilverBullet_Signals.mq5`
- Statut : logique implémentée et couverte par les tests automatisés décrits en
  section 14 ; performance et comportement broker réel restant à valider

## 1. Objet et séquence générale

La stratégie recherche une continuation après une purge de liquidité, une
confirmation de structure interne et un retracement dans la bonne moitié du
dealing range.

Le chemin ci-dessous est celui du profil strict de référence :

```text
Biais D1 + stacking D1/H1/M5/M1 complets
    ↓
Purge clôturée de la liquidité opposée au futur trade
    ↓
Formation et confirmation d'une structure interne post-purge
    ↓
Balayage de la cible externe dans le sens du futur trade
    ↓
MSS sur la structure interne + déplacement + FVG directionnelle
    ↓
Construction du dealing range
    ↓
Retracement et déclencheur dans la même fenêtre New York
    ↓
Ordre au marché et réconciliation du fill réel
```

Principes obligatoires :

- seules des bougies clôturées alimentent les décisions ;
- les événements sont horodatés et respectent cet ordre dans le profil strict ;
  seuls les détours bornés `TBI1` et `MBT1` décrits plus bas peuvent mémoriser
  une cible ou un MSS causal dans l'ordre alternatif autorisé ;
- aucun MSS ou pivot interne antérieur à la purge ne peut valider un setup ;
- une liquidité balayée est consommée et ne peut pas recréer indéfiniment le
  même setup ;
- un stack incomplet ou neutre interdit le trade et le signal ;
- la FVG est obligatoire, quel que soit le déclencheur final ;
- la purge, les confirmations et l'entrée appartiennent à une même instance de
  fenêtre horaire autorisée ;
- le prix doit réellement traiter la zone choisie ;
- l'EA et l'indicateur doivent utiliser le même moteur de décision partagé.

Les swings externes servant de liquidité peuvent naturellement avoir été formés
avant la fenêtre. La contrainte « même fenêtre » commence avec la purge.

### 1.1 Profil normatif et profil expérimental

La séquence de ce document reste définie par le **profil strict de référence**.
Les variantes configurables servent à mesurer la fréquence et la robustesse ;
elles ne remplacent pas cette cible normative et ne constituent aucune
validation de performance.

```text
Profil strict de référence
EP2 / P2 / MBT0 / TBI0 / DR1 / FVC1 / ET0

Profil expérimental fréquence
Timeframe d'exécution M1 / EP1 / P1 / MBT1 / TBI1 / DR0 / FVC4 / ET10
```

Dans le profil expérimental, `M1` désigne le timeframe du graphique et de
l'exécution. Il ne modifie pas le stacking directeur, qui reste obligatoirement
D1/H1/M5/M1. Le profil strict ne fixe pas ici un timeframe d'exécution.

| Code | Input | Sens |
|---|---|---|
| `P` | `InpInternalPivotStrength` (`1` ou `2`) | Force 1/1 ou 2/2 du pivot interne post-purge utilisé par le MSS |
| `EP` | `InpExternalPivotStrength` (`1` ou `2`) | Force 1/1 ou 2/2 des références externes de liquidité, indépendante de `P` |
| `MBT` | `InpAllowMssBeforeTarget` | `0` impose cible puis MSS ; `1` peut mémoriser un MSS causal antérieur à la cible |
| `TBI` | `InpAllowTargetBeforeInternalPivot` | `0` impose pivot interne puis cible ; `1` peut mémoriser une cible antérieure au pivot |
| `DR` | `InpRequireDirectionalRejection` | `1` exige le rejet directionnel au trigger ; `0` retire seulement cette exigence |
| `FVC` | `InpMaxFvgCandidates` (`1` à `4`) | Capacité du pool de FVG candidates post-purge |
| `ET` | `InpEntryEqToleranceTicks` (`0` à `50`) | Tolérance d'exécution de l'EA autour d'EQ uniquement |

L'indicateur Signals partage tous les réglages du moteur Core de ce tableau
(`P`, `EP`, `MBT`, `TBI`, `DR`, `FVC`). Il n'expose pas `ET`, puisque cette
tolérance intervient seulement sur la cotation et le fill réels de l'EA, après
la décision du moteur.

## 2. Biais et stacking obligatoires

### 2.1 LONG

Le biais est haussier uniquement lorsque la dernière bougie D1 clôturée vérifie :

```text
Close D1 > EMA10 D1 > EMA20 D1
```

H1, M5 et M1 doivent simultanément vérifier le même stacking haussier.

### 2.2 SHORT

Le biais est baissier uniquement lorsque la dernière bougie D1 clôturée vérifie :

```text
Close D1 < EMA10 D1 < EMA20 D1
```

H1, M5 et M1 doivent simultanément vérifier le même stacking baissier.

### 2.3 Neutralité

Si D1, H1, M5 ou M1 n'est pas complètement aligné :

```text
Biais = NEUTRE
Trade = INTERDIT
Signal = INTERDIT
```

Un ancien biais n'est jamais conservé pendant un empilement EMA neutre. Les
périodes de référence sont obligatoirement EMA10 et EMA20.

## 3. Références structurelles

Avant une purge, le système mémorise un swing high externe et un swing low
externe confirmés, avec leurs prix et timestamps. Ces deux références restent
figées pendant la vie du setup.

Après la purge, une seconde structure, interne à la nouvelle jambe, doit se
former puis être confirmée :

- LONG : un swing high interne ;
- SHORT : un swing low interne.

Dans le profil strict de référence, un swing interne est un pivot strict 2/2 :
deux bougies à gauche et deux à droite (`P2`). Le mode expérimental `P1` utilise
une bougie de chaque côté. Dans les deux cas, les comparaisons de prix du pivot
restent strictes, sa bougie source doit être strictement postérieure à la purge,
et le premier pivot interne éligible est verrouillé sans remplacement au milieu
de la séquence.

Le niveau externe balayé et le niveau interne cassé par le MSS sont donc deux
niveaux distincts.

À chaque clôture, deux flux indépendants évaluent chacun un pivot high et un
pivot low : `P` pour la structure interne et `EP` pour les références externes.
Le mode 1/1 prend `b-1` comme candidat confirmé par `b`; le mode 2/2 prend `b-2`
comme candidat confirmé par `b`. Modifier `EP` ne décale donc jamais `P`, et
réciproquement. Un pivot interne confirmé sur la bougie courante peut servir à
un setup antérieur. Un pivot externe confirmé sur cette bougie ne devient une
référence qu'après son traitement complet et ne peut pas réécrire la liquidité,
la purge ou la cible déjà évaluées. Dans chacun des deux flux, si une même
bougie « outside » satisfait simultanément les critères stricts de pivot high et
de pivot low, les deux événements de cette paire sont rejetés comme ambigus.

## 4. Préparation d'un achat

### Étape 1 - Admission

Les conditions partagées par l'EA et l'indicateur sont :

- stacking D1/H1/M5/M1 haussier complet ;
- direction LONG autorisée ;
- swing low et swing high externes disponibles et non consommés ;
- clôture de la bougie dans une fenêtre autorisée.

L'EA exige en plus un verrou journalier inactif et le respect des limites de
positions, de capacité et de risque du compte. L'indicateur ne connaît pas ces
états de compte : son `InpMaxPositions` plafonne uniquement ses setups candidats.

### Étape 2 - Purge clôturée du swing low

La purge LONG exige à la fois une mèche stricte sous le swing low et une clôture
de réintégration stricte au-dessus de ce niveau :

```text
Low < SwingLowExterne
AND Close > SwingLowExterne
```

Une clôture exactement égale au swing low n'est pas une réintégration. Le plus
bas de cette bougie devient Fibonacci `0` et reste verrouillé.

### Étape 3 - Structure interne post-purge

Un swing high interne doit ensuite se former et être confirmé. Sa bougie source,
son prix, sa bougie de confirmation et leurs timestamps sont mémorisés. Il est
2/2 dans le profil strict (`P2`) et peut être 1/1 dans le profil expérimental
(`P1`), sans jamais accepter une source antérieure ou égale à la purge.

### Étape 4 - Balayage de la cible externe

Dans le profil strict (`TBI0`), une bougie clôturée doit, après confirmation du
swing interne, avoir traité au-dessus du swing high externe :

```text
High > SwingHighExterne
```

La mèche suffit pour ce balayage de liquidité externe. Le swing high externe est
consommé dès son premier balayage, qu'une entrée soit finalement produite ou non.
Avec `TBI1`, ce premier balayage peut être mémorisé avant la confirmation du
pivot interne ; le setup attend alors ce pivot puis un MSS causal. La bougie qui
confirme le pivot ne peut pas fournir rétroactivement le MSS.

### Étape 5 - MSS interne, déplacement et FVG

Le MSS LONG est une nouvelle clôture qui traverse le swing high interne :

```text
ClosePrecedente <= SwingHighInterne
AND Close > SwingHighInterne
```

Le simple dépassement par une mèche ne suffit pas. Le vrai croisement empêche de
réutiliser une clôture déjà installée au-dessus du niveau.

Avec `MBT0`, le balayage externe doit précéder le MSS. Le balayage et le MSS
peuvent être confirmés sur la même bougie fermée si le pivot interne était déjà
confirmé : le high traite la cible, puis la clôture confirme le MSS. Avec
`MBT1`, le premier vrai croisement strictement postérieur à la confirmation du
pivot peut être mémorisé avant la cible, sans remplir encore les champs du MSS
validé ; il n'est promu qu'après une cible strictement ultérieure. Aucun de ces
événements ne peut être réutilisé depuis la bougie de purge.

La jambe doit aussi produire :

- un déplacement minimal mesurable ;
- une FVG haussière formée entièrement après la purge ;
- une Consequent Encroachment de FVG située en discount.

Une FVG candidate formée après la purge peut être mémorisée avant le MSS. `FVC1`
conserve le comportement strict historique avec une candidate ; une valeur
`FVC2` à `FVC4` maintient un pool borné de candidates valides. Une candidate ne
devient la FVG de contexte qu'une fois le balayage externe, le MSS et le
déplacement tous confirmés.

### Étape 6 - Dealing range LONG

```text
Fib0  = plus bas de la bougie de purge
Fib1  = plus haut atteint par la jambe de déplacement
Range = Fib1 - Fib0
EQ    = Fib0 + 0,50 × Range
Discount = [Fib0 ; EQ]
```

Fib0 reste fixe. Fib1 suit l'extrême de la jambe, puis est figé lorsque
balayage, MSS, déplacement et FVG de contexte sont confirmés.

### Étape 7 - Retracement et entrée LONG

Sur une bougie ultérieure, dans la même instance de fenêtre, le prix doit
retracer en discount. Avec `DR1`, la bougie doit aussi produire un rejet
haussier ; avec `DR0`, cette seule exigence de rejet/couleur est retirée. Le
déclencheur peut être :

- le toucher réel de la CE de la FVG haussière ;
- l'intersection réelle du range de la bougie avec la zone OTE inclusive 62–79 % ;
- un retest EMA10 dont le niveau est lui-même en discount.

La clôture de confirmation et le prix encore exécutable doivent être en
discount. Un EMA en premium, une portion interdite de FVG ou un niveau OTE non
traité ne peuvent pas devenir un prix théorique d'entrée. La tolérance `ET`,
décrite en section 10, ne s'applique qu'au prix de l'EA après cette décision.

## 5. Préparation d'une vente

La logique SHORT est le miroir exact de la logique LONG.

### Étape 1 - Admission

- stacking D1/H1/M5/M1 baissier complet ;
- direction SHORT autorisée ;
- références externes présentes et non consommées ;
- clôture de la bougie dans une fenêtre autorisée.

Les contraintes opérationnelles ont la même portée que pour un LONG : verrou,
positions et risque sont contrôlés par l'EA, tandis que l'indicateur ne limite que
ses setups candidats.

### Étape 2 - Purge clôturée du swing high

```text
High > SwingHighExterne
AND Close < SwingHighExterne
```

Une clôture exactement égale est refusée. Le plus haut de cette bougie devient
Fibonacci `0` et reste verrouillé.

### Étape 3 - Structure interne post-purge

Un swing low interne strict, formé après la purge, est mémorisé sans remplacement
ultérieur. Sa confirmation utilise deux bougies de chaque côté avec `P2`, ou une
de chaque côté avec `P1`.

### Étape 4 - Balayage de la cible externe

Avec `TBI0`, le balayage suivant doit arriver après confirmation du swing
interne :

```text
Low < SwingLowExterne
```

Le swing low externe est alors consommé.
Avec `TBI1`, il peut être mémorisé plus tôt selon la même règle causale que pour
un LONG, sans permettre un MSS rétroactif sur la confirmation du pivot.

### Étape 5 - MSS interne, déplacement et FVG

```text
ClosePrecedente >= SwingLowInterne
AND Close < SwingLowInterne
```

Le MSS est postérieur à la purge et utilise la structure interne, pas le swing
low externe. Avec `MBT0`, la cible doit le précéder ; avec `MBT1`, un premier
croisement causal peut être mémorisé puis promu après une cible ultérieure. Le
balayage externe et le MSS peuvent appartenir à la même bougie fermée si le
pivot interne était déjà confirmé.

La jambe doit produire un déplacement minimal, une FVG baissière post-purge et
une CE située en premium.

### Étape 6 - Dealing range SHORT

```text
Fib0  = plus haut de la bougie de purge
Fib1  = plus bas atteint par la jambe de déplacement
Range = Fib0 - Fib1
EQ    = Fib1 + 0,50 × Range
Premium = [EQ ; Fib0]
```

### Étape 7 - Retracement et entrée SHORT

Sur une bougie ultérieure et dans la même instance de fenêtre, l'un des
déclencheurs suivants doit être réellement traité. `DR1` exige en plus un rejet
baissier ; `DR0` retire uniquement cette exigence :

- CE de la FVG baissière ;
- intersection du range de la bougie avec la zone OTE inclusive 62–79 % ;
- EMA10 située en premium.

La clôture et le prix exécutable doivent rester en premium.

## 6. Fibonacci, OTE et FVG

### 6.1 OTE

```text
OTE Long  = [Fib1 - 0,79 × Range ; Fib1 - 0,62 × Range]
OTE Short = [Fib1 + 0,62 × Range ; Fib1 + 0,79 × Range]
```

Les deux bornes sont inclusives et réellement contrôlées. Le niveau indicatif
70,5 % ne remplace jamais une zone traitée ni le fill réel.

### 6.2 Définition de la FVG

Sur trois bougies clôturées, `n` étant la plus récente :

```text
FVG haussière : Low[n]  > High[n-2]
FVG baissière : High[n] < Low[n-2]
```

Les bornes sont toujours ordonnées `FvgLow <= FvgHigh`, la largeur minimale est
appliquée et les trois bougies sont postérieures à la purge.

### 6.3 Consequent Encroachment

```text
CE = (FvgLow + FvgHigh) / 2
```

Une FVG est dans la bonne moitié si :

```text
LONG  : Fib0 <= CE <= EQ
SHORT : EQ <= CE <= Fib0
```

La FVG entière n'a pas besoin d'être contenue dans la moitié autorisée. Elle peut
traverser EQ si sa CE reste du bon côté. Si la FVG sert de déclencheur, le range
de la bougie doit réellement toucher sa CE ; toucher seulement la portion située
du mauvais côté d'EQ ne suffit pas.

Après promotion en contexte, la règle d'invalidation reste :

- LONG : clôture sous la borne basse de la FVG ;
- SHORT : clôture au-dessus de la borne haute de la FVG.

### 6.4 Pool de FVG candidates

`InpMaxFvgCandidates` est borné de 1 à 4. `FVC1` conserve une seule candidate et
correspond au comportement strict historique. `FVC2` à `FVC4` permettent de
conserver plusieurs candidates post-purge encore valides avant la promotion de
la FVG de contexte. Cette capacité ne rend pas optionnelles la direction, la
formation post-purge, la CE dans la bonne moitié, le déplacement, le toucher du
trigger ni l'invalidation distale.

## 7. Fenêtres obligatoires

Toutes les heures sont celles de New York. La conversion applique le DST valable
à la date de clôture de chaque bougie. Les intervalles sont semi-ouverts : début
inclus, fin exclue.

| Instance | Fenêtre autorisée |
|---|---:|
| London Killzone | `[02:00,05:00)` |
| New York Killzone | `[07:00,10:00)` |
| Asian Killzone | `[19:00,22:00)` |

Ces trois fenêtres sont séparées et totalisent 540 minutes par jour New York.
05:00, 10:00 et 22:00 sont refusées.

La purge ne peut créer un setup qu'à l'intérieur d'une de ces fenêtres. Chaque
setup mémorise `date New York + identifiant de fenêtre`. Tous ses événements
suivants doivent conserver exactement cet identifiant. Une sortie de fenêtre,
un passage au jour suivant ou un trou de cotations menant directement à une
autre fenêtre invalide immédiatement le setup. Aucun report à la prochaine
Killzone n'est autorisé.

`InpUseSbWindows` peut être conservé dans les fichiers pour compatibilité avec
les anciens presets, mais la norme exige sa valeur `true`; une valeur `false`
doit faire échouer l'initialisation au lieu de désactiver cette règle.
De même, `InpAutoDST` doit rester à `true` : un offset New York manuel fixe est
incompatible avec l'exigence d'appliquer EST/EDT à la date de chaque bougie.

## 8. Machine d'état normative

Le chemin principal du profil strict de référence est :

```text
WAIT_STACK
    ↓ alignement complet
WAIT_REFERENCE_SWINGS
    ↓ références externes verrouillées
WAIT_LIQUIDITY_PURGE
    ↓ mèche + clôture de réintégration, dans une fenêtre
WAIT_INTERNAL_STRUCTURE
    ↓ pivot interne post-purge confirmé
WAIT_TARGET_SWEEP
    ↓ cible externe balayée et consommée
WAIT_INTERNAL_MSS
    ↓ vrai croisement clôturé du pivot interne
WAIT_DISPLACEMENT_FVG_CE
    ↓ déplacement + FVG obligatoire dont CE est correcte
WAIT_RETRACEMENT_WINDOW
    ↓ déclencheur réellement traité dans la même fenêtre
READY_TO_ENTER
    ↓ ordre marché accepté et fill réconcilié
POSITION_MANAGEMENT
```

Le moteur peut effectuer plusieurs transitions compatibles sur une même bougie
fermée, mais il ne fabrique jamais un ordre temporel impossible. En particulier,
avec `TBI0`, le pivot interne doit déjà être confirmé avant le balayage externe ;
avec `MBT0`, la cible doit précéder le MSS. Le balayage et la clôture MSS peuvent
ensuite être constatés sur la même bougie si le pivot était déjà confirmé.

Deux détours expérimentaux sont explicitement bornés :

- `TBI1` peut enregistrer une cible dans `WAIT_INTERNAL_STRUCTURE`, puis attend
  le pivot interne avant de passer à l'attente du MSS ;
- `MBT1` peut enregistrer un MSS causal après confirmation du pivot tout en
  restant dans l'attente de la cible, puis le promouvoir seulement lorsque la
  cible arrive sur une bougie strictement ultérieure.

Ces détours n'autorisent ni événement pré-purge, ni MSS sur la bougie même de
confirmation du pivot, ni réutilisation d'une cible consommée.

Chaque setup mémorise au minimum :

- direction et phase ;
- swings externes, prix, timestamps et clés de consommation ;
- purge, extrême, clôture, Fib0 et instance de fenêtre ;
- pivot interne, source et confirmation ;
- balayage externe ;
- MSS interne et clôture précédente ;
- extrême de jambe, Fib1 et EQ ;
- FVG candidate, FVG de contexte, CE et timestamps ;
- expiration, déclencheur et décision d'entrée ;
- dans l'EA seulement : ticket, identifiant de position, fill et volume réels.

## 9. Invalidations et consommation

Le setup est invalidé lorsque :

- le stacking complet disparaît ou s'oppose à la direction ;
- l'instance de fenêtre change ou devient absente ;
- son âge dépasse la limite configurée ;
- une clôture LONG passe strictement sous Fib0, ou une clôture SHORT strictement
  au-dessus de Fib0 ;
- avec `TBI0`, la cible externe est balayée avant la confirmation d'une
  structure interne ; avec `TBI1`, elle est mémorisée une seule fois ;
- avec `MBT0`, la structure interne est cassée avant le balayage externe ; avec
  `MBT1`, seul le premier vrai croisement causal peut rester en attente ;
- un pivot antérieur à la purge est présenté comme structure interne ;
- la FVG obligatoire de contexte est invalidée ;
- dans l'EA, le verrou journalier devient actif.

Une FVG encore candidate peut être retirée ou remplacée si elle est invalidée
avant sa promotion, dans la limite du pool `FVC`. Une FVG de contexte déjà
promue invalide le setup selon ses bornes distales.

Une limite de positions, un risque non admissible ou un prix marché devenu
inexécutable ne constituent pas, à eux seuls, une invalidation d'un setup déjà en
attente. Lorsqu'une décision d'entrée ne peut pas être exécutée, l'EA revient en
`WAIT_RETRACEMENT` et attend un nouveau retracement valide dans la même fenêtre.
À l'étape de création, en revanche, une capacité insuffisante empêche le setup de
naître et la liquidité déjà balayée reste consommée.

Exception de sûreté : lorsqu'une requête d'ouverture a été envoyée mais que son
résultat broker n'est pas confirmé, l'EA conserve une sentinelle, bloque cette
capacité et recherche le deal, l'ordre ou la position réels. Toute exécution
tardive détectée est fermée de sécurité ; la décision n'est jamais réarmée. Les
transactions, l'historique et les ordres actifs sont consultés pendant
`InpBrokerReconcileSeconds` (120 secondes par défaut). Après ce délai, une
requête sans ordre actif ni preuve d'exécution est considérée terminée ; la
liquidité reste néanmoins consommée.

Les mèches qui prennent une liquidité doivent être enregistrées même lorsque la
réintégration, le stack, le risque, la fenêtre ou la capacité empêchent la
création d'un setup. Cela empêche une bougie ultérieure de réutiliser un niveau
déjà traité comme une nouvelle purge.

## 10. Déclenchement, risque et exécution

Le seul mode d'entrée retenu est un ordre au marché au premier tick suivant la
clôture de la bougie de confirmation. Aucun ordre limite n'est prévu par cette
révision.

Avant l'envoi :

- la zone FVG/OTE/EMA doit avoir été réellement traitée ;
- la clôture et le prix marché courant doivent être dans la moitié autorisée ;
- le timestamp du tick exécutable doit encore appartenir à l'instance de fenêtre
  mémorisée par le setup ;
- le volume est calculé depuis le prix réellement exécutable et le SL
  structurel ;
- les limites de risque et de positions sont revérifiées.

`InpEntryEqToleranceTicks` (`ET`, borné de 0 à 50) est une tolérance
**d'exécution EA autour d'EQ seulement**. Elle n'entre pas dans le Core et ne
change jamais la validation de la bougie clôturée :

```text
LONG  : prix exécutable dans [Fib0 ; EQ + ET × tailleTick]
SHORT : prix exécutable dans [EQ - ET × tailleTick ; Fib0]
```

Fib0 reste donc une borne dure : aucune valeur de `ET` ne tolère un prix sous
Fib0 pour un LONG ou au-dessus de Fib0 pour un SHORT. `ET` ne déplace ni Fib0,
ni l'origine, ni le SL, ni une zone FVG/OTE/EMA. La cotation avant envoi et le
fill réel sont tous deux contrôlés avec ces bornes. `ET0` est le profil strict ;
`ET10` étend uniquement la borne EQ de dix ticks dans le profil expérimental.
Signals n'expose pas cet input puisqu'il ne réalise aucune exécution.

Après l'envoi :

- le retcode est contrôlé ;
- `PLACED`, `TIMEOUT`, `LOCKED` et `DONE_PARTIAL` sont réconciliés avant toute
  nouvelle requête portant sur la même entrée ou la même sortie ;
- tout reliquat actif d'une entrée partiellement remplie est annulé et son
  annulation réconciliée avant la fermeture de sécurité ;
- les modifications SL/TP sont sérialisées et leur effet est relu sur la
  position avant d'armer break-even ou trailing ;
- prix et volume sont lus depuis le deal ou la position ;
- R, TP1, TP final et risque réel sont réconciliés depuis le fill ;
- si le fill ou les protections ne sont pas sûrs, l'EA ferme la position de
  sécurité ;
- aucun prix de clôture théorique n'est conservé comme prix d'exécution.

La comparaison du risque réel après fill admet uniquement une tolérance
numérique égale à :

```text
max(0,01 % du budget de risque ; 0,05 $)
```

Elle absorbe le bruit d'arrondi monétaire. Elle ne modifie pas le pourcentage de
risque demandé et ne constitue pas une marge discrétionnaire de sur-risque.

## 11. Sorties recommandées

La logique d'entrée ne démontre pas à elle seule un ratio de sortie optimal. La
baseline prudente recommandée pour les prochains backtests est :

- SL structurel au-delà de Fib0 avec buffer ;
- TP1 à 2 R ;
- 50 % du volume fermé à TP1 ;
- reliquat déplacé à break-even après confirmation du TP1 ;
- TP final initial à 4 R ;
- si le trailing est désactivé, maintien du TP final à 4 R ;
- si le trailing est activé, retrait du TP final après TP1 puis trailing du
  runner à 2 R depuis son extrême favorable ;
- gestion évaluée à chaque tick et protections initiales placées chez le broker.

Cette baseline est préférable comme point de départ car elle matérialise assez
tôt une partie du gain tout en conservant un runner significatif. Elle reste à
valider séparément sur DE30 et XAUUSD par vrais ticks, coûts réalistes, IS/OOS et
Monte-Carlo. Les anciens presets 2,5 R / 30 % / 6 R / 2,5 R restent des variantes
historiques, pas une preuve d'optimalité.

## 12. Critères d'acceptation

Les deux scénarios ci-dessous décrivent le profil strict de référence
`EP2/P2/MBT0/TBI0/DR1/FVC1/ET0`.

### LONG valide

```text
Stack haussier complet dans D1/H1/M5/M1
→ purge du swing low avec clôture de réintégration
→ swing high interne formé et confirmé après la purge
→ swing high externe balayé
→ clôture MSS au-dessus du swing high interne
→ déplacement et FVG haussière avec CE en discount
→ retracement ultérieur réellement traité en discount
→ toute la séquence depuis la purge dans la même fenêtre
→ achat au marché puis fill réel réconcilié
```

### SHORT valide

```text
Stack baissier complet dans D1/H1/M5/M1
→ purge du swing high avec clôture de réintégration
→ swing low interne formé et confirmé après la purge
→ swing low externe balayé
→ clôture MSS sous le swing low interne
→ déplacement et FVG baissière avec CE en premium
→ retracement ultérieur réellement traité en premium
→ toute la séquence depuis la purge dans la même fenêtre
→ vente au marché puis fill réel réconcilié
```

### Rejets obligatoires du profil strict de référence

- stack incomplet sur l'un des quatre timeframes ;
- simple mèche de purge sans clôture de réintégration ;
- clôture de purge égale au swing ;
- pivot interne source antérieur ou égal à la purge ;
- cible externe balayée avant confirmation du pivot interne avec `TBI0` ;
- MSS interne avant cible externe avec `MBT0`, par mèche seulement ou sans vrai
  croisement dans tous les modes ;
- FVG dont la CE est dans la mauvaise moitié ;
- toucher de la FVG sans toucher sa CE lorsqu'elle sert de déclencheur ;
- absence de rejet/couleur directionnel avec `DR1` ; avec `DR0`, les autres
  conditions du trigger restent obligatoires ;
- EMA hors discount/premium ;
- OTE en dehors de 62–79 % ;
- sortie de fenêtre ou tentative de report à la fenêtre suivante ;
- réutilisation d'une liquidité consommée ;
- prix théorique jamais traité ;
- dépassement des limites de risque ou d'exposition.

Dans le profil expérimental, seules les trois portes explicitement activées par
`TBI1`, `MBT1` et `DR0` cessent d'être des rejets absolus. Les contrôles de
causalité post-purge, de vrai croisement, de FVG, de moitié du range, de fenêtre,
de consommation et de risque restent inchangés. `ET10` ne concerne que le prix
EA autour d'EQ et ne peut jamais franchir Fib0.

## 13. Décisions de la révision du 9 août 2026

Les décisions ci-dessous constituent le profil strict de référence ; elles ne
sont pas remplacées par le profil expérimental fréquence.

1. stacking obligatoire : D1 + H1 + M5 + M1, tous en EMA10/EMA20 ;
2. purge : mèche stricte et clôture de réintégration stricte ;
3. MSS : vrai croisement clôturé d'un pivot interne 2/2 formé post-purge (`P2`) ;
4. structure interne, cible externe et MSS : événements distincts dans cet
   ordre (`TBI0`, `MBT0`) ;
5. FVG : validation par sa CE, pas par l'intégralité de la zone ;
6. entrée : uniquement au marché après bougie clôturée ;
7. fenêtres séparées et obligatoires : `[02:00,05:00)`, `[07:00,10:00)` et
   `[19:00,22:00)` New York ;
8. conservation : aucun passage d'une fenêtre à une autre ;
9. sorties : baseline 2 R / 50 % / 4 R / trailing 2 R, configurable et à
   valider empiriquement ;
10. horaire : clôture nominale de la bougie, conversion broker historique vers
    UTC puis New York avec DST applicable à cette date.

Les inputs `EP`, `P`, `TBI`, `MBT`, `DR` et `FVC` rendent testables les variantes
bornées décrites en section 1.1. `ET` reste extérieur au moteur et ne modifie que
le contrôle du prix exécutable autour d'EQ.

## 14. Validation attendue

La suite automatisée doit couvrir au minimum :

- les égalités et inégalités strictes du stack et de la purge ;
- les pivots internes et externes 1/1 ou 2/2, leurs buffers indépendants et leur
  chronologie post-purge ;
- la séparation cible externe / MSS interne, les modes stricts et flexibles
  `TBI`/`MBT`, et leur symétrie LONG/SHORT ;
- les vrais croisements, l'idempotence et la consommation des liquidités ;
- le rejet directionnel obligatoire avec `DR1` et sa seule relaxation avec
  `DR0` ;
- le pool de une à quatre FVG candidates, leur invalidation et leur promotion ;
- la CE sous, sur et au-delà de l'EQ, y compris une FVG traversant l'EQ ;
- le toucher réel de la CE, les bornes OTE et le retest EMA ;
- exactement 540 minutes quotidiennes admises ;
- les bornes 02:00/05:00, 07:00/10:00 et 19:00/22:00 ;
- la transition DST US et la conversion historique du broker ;
- l'invalidation lors d'un changement d'instance de fenêtre ou d'un trou de
  cotations ;
- la parité de l'EA et de l'indicateur avec le moteur partagé ;
- la réconciliation d'une réponse broker incertaine et d'un fill TP1 partiel ;
- `ET` appliqué uniquement à la borne EQ de la cotation et du fill, jamais à
  Fib0, ainsi que la tolérance de risque `max(0,01 % ; 0,05 $)` ;
- la compilation réelle des deux fichiers MQL5 sans erreur ni avertissement.

Ces tests empêchent les régressions logiques et syntaxiques. Ils ne remplacent
pas une campagne Strategy Tester en vrais ticks, des essais de redémarrage ni la
validation des fills, du slippage et des clôtures partielles chez le broker.

## Conclusion

- **LONG** : purge clôturée du swing low, structure interne post-purge, sweep du
  swing high externe, MSS interne, déplacement/FVG dont la CE est en discount,
  puis retracement et achat marché dans la même fenêtre ;
- **SHORT** : miroir exact avec purge clôturée du swing high, structure interne,
  sweep du swing low externe, MSS, CE en premium et vente marché ;
- **aucun stack complet** : aucun setup, signal ou trade ;
- **Fib0** : extrême verrouillé de la bougie de purge ;
- **horaires** : `[02:00,05:00)`, `[07:00,10:00)` et `[19:00,22:00)`, heure de
  New York, sans conservation inter-fenêtre.
