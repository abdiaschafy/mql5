# Spécification de référence des entrées et sorties

- Date de mise à jour : 9 août 2026
- Révision historique citée : `9178b72`
- Composants : `ICT_SilverBullet_Core.mqh`, `ICT_SilverBullet_Strategy.mq5` et `ICT_SilverBullet_Signals.mq5`
- Statut : logique implémentée et couverte par les tests automatisés décrits en
  section 14 ; performance et comportement broker réel restant à valider

## 1. Objet et séquence générale

La stratégie recherche une continuation après une purge de liquidité, une
confirmation de structure interne et un retracement dans la bonne moitié du
dealing range.

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
- les événements sont horodatés et respectent l'ordre défini ci-dessus ;
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

Règle déterministe retenue pour les deux composants : un swing interne est un
pivot strict confirmé par deux bougies de chaque côté. La bougie source du pivot
doit être strictement postérieure à la bougie de purge. Le premier pivot interne
éligible est verrouillé et ne peut plus être remplacé au milieu de la séquence.

Le niveau externe balayé et le niveau interne cassé par le MSS sont donc deux
niveaux distincts.

À chaque clôture, le détecteur 2/2 évalue indépendamment un pivot high et un
pivot low. Un pivot confirmé sur la bougie courante peut déjà servir de structure
interne à un setup antérieur, mais il ne devient une nouvelle référence externe
qu'après le traitement complet de cette bougie. Il ne peut donc pas réécrire la
liquidité, la purge ou la cible évaluées sur sa propre bougie de confirmation.
Si une même bougie « outside » satisfait simultanément les critères stricts du
pivot high et du pivot low, les deux événements sont rejetés comme ambigus.

## 4. Préparation d'un achat

### Étape 1 — Admission

Les conditions partagées par l'EA et l'indicateur sont :

- stacking D1/H1/M5/M1 haussier complet ;
- direction LONG autorisée ;
- swing low et swing high externes disponibles et non consommés ;
- clôture de la bougie dans une fenêtre autorisée.

L'EA exige en plus un verrou journalier inactif et le respect des limites de
positions, de capacité et de risque du compte. L'indicateur ne connaît pas ces
états de compte : son `InpMaxPositions` plafonne uniquement ses setups candidats.

### Étape 2 — Purge clôturée du swing low

La purge LONG exige à la fois une mèche stricte sous le swing low et une clôture
de réintégration stricte au-dessus de ce niveau :

```text
Low < SwingLowExterne
AND Close > SwingLowExterne
```

Une clôture exactement égale au swing low n'est pas une réintégration. Le plus
bas de cette bougie devient Fibonacci `0` et reste verrouillé.

### Étape 3 — Structure interne post-purge

Un swing high interne doit ensuite se former et être confirmé. Sa bougie source,
son prix, sa bougie de confirmation et leurs timestamps sont mémorisés.

### Étape 4 — Balayage de la cible externe

Après confirmation du swing interne, une bougie clôturée doit avoir traité au-
dessus du swing high externe :

```text
High > SwingHighExterne
```

La mèche suffit pour ce balayage de liquidité externe. Le swing high externe est
consommé dès son premier balayage, qu'une entrée soit finalement produite ou non.

### Étape 5 — MSS interne, déplacement et FVG

Le MSS LONG est une nouvelle clôture qui traverse le swing high interne :

```text
ClosePrecedente <= SwingHighInterne
AND Close > SwingHighInterne
```

Le simple dépassement par une mèche ne suffit pas. Le vrai croisement empêche de
réutiliser une clôture déjà installée au-dessus du niveau.

Le balayage externe et le MSS peuvent être confirmés sur la même bougie fermée
si le pivot interne était déjà confirmé : le high de la bougie traite la cible,
puis la clôture finale confirme le MSS. Ils ne peuvent jamais être réutilisés
depuis la bougie de purge.

La jambe doit aussi produire :

- un déplacement minimal mesurable ;
- une FVG haussière formée entièrement après la purge ;
- une Consequent Encroachment de FVG située en discount.

Une FVG candidate formée après la purge peut être mémorisée avant le MSS. Elle ne
devient la FVG de contexte qu'une fois le balayage externe, le MSS et le
déplacement tous confirmés.

### Étape 6 — Dealing range LONG

```text
Fib0  = plus bas de la bougie de purge
Fib1  = plus haut atteint par la jambe de déplacement
Range = Fib1 - Fib0
EQ    = Fib0 + 0,50 × Range
Discount = [Fib0 ; EQ]
```

Fib0 reste fixe. Fib1 suit l'extrême de la jambe, puis est figé lorsque
balayage, MSS, déplacement et FVG de contexte sont confirmés.

### Étape 7 — Retracement et entrée LONG

Sur une bougie ultérieure, dans la même instance de fenêtre, le prix doit
retracer en discount et produire un rejet haussier. Le déclencheur peut être :

- le toucher réel de la CE de la FVG haussière ;
- l'intersection réelle du range de la bougie avec la zone OTE inclusive 62–79 % ;
- un retest EMA10 dont le niveau est lui-même en discount.

La clôture de confirmation et le prix encore exécutable doivent être en
discount. Un EMA en premium, une portion interdite de FVG ou un niveau OTE non
traité ne peuvent pas devenir un prix théorique d'entrée.

## 5. Préparation d'une vente

La logique SHORT est le miroir exact de la logique LONG.

### Étape 1 — Admission

- stacking D1/H1/M5/M1 baissier complet ;
- direction SHORT autorisée ;
- références externes présentes et non consommées ;
- clôture de la bougie dans une fenêtre autorisée.

Les contraintes opérationnelles ont la même portée que pour un LONG : verrou,
positions et risque sont contrôlés par l'EA, tandis que l'indicateur ne limite que
ses setups candidats.

### Étape 2 — Purge clôturée du swing high

```text
High > SwingHighExterne
AND Close < SwingHighExterne
```

Une clôture exactement égale est refusée. Le plus haut de cette bougie devient
Fibonacci `0` et reste verrouillé.

### Étape 3 — Structure interne post-purge

Un swing low interne strict, formé après la purge et confirmé par deux bougies de
chaque côté, est mémorisé sans remplacement ultérieur.

### Étape 4 — Balayage de la cible externe

Après confirmation du swing interne :

```text
Low < SwingLowExterne
```

Le swing low externe est alors consommé.

### Étape 5 — MSS interne, déplacement et FVG

```text
ClosePrecedente >= SwingLowInterne
AND Close < SwingLowInterne
```

Le MSS est postérieur à la purge et utilise la structure interne, pas le swing
low externe. Le balayage externe et le MSS peuvent appartenir à la même bougie
fermée si le pivot interne était déjà confirmé.

La jambe doit produire un déplacement minimal, une FVG baissière post-purge et
une CE située en premium.

### Étape 6 — Dealing range SHORT

```text
Fib0  = plus haut de la bougie de purge
Fib1  = plus bas atteint par la jambe de déplacement
Range = Fib0 - Fib1
EQ    = Fib1 + 0,50 × Range
Premium = [EQ ; Fib0]
```

### Étape 7 — Retracement et entrée SHORT

Sur une bougie ultérieure et dans la même instance de fenêtre, un rejet baissier
doit réellement traiter l'un des déclencheurs suivants :

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
le pivot interne doit déjà être confirmé avant le balayage externe ; le balayage
et la clôture MSS peuvent ensuite être constatés sur la même bougie.

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
- la cible externe est balayée avant la confirmation d'une structure interne ;
- la structure interne est cassée avant le balayage externe ;
- un pivot antérieur à la purge est présenté comme structure interne ;
- la FVG obligatoire de contexte est invalidée ;
- dans l'EA, le verrou journalier devient actif.

Une FVG encore candidate peut être remplacée si elle est invalidée avant sa
promotion. Une FVG de contexte déjà promue invalide le setup selon ses bornes
distales.

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

### Rejets obligatoires

- stack incomplet sur l'un des quatre timeframes ;
- simple mèche de purge sans clôture de réintégration ;
- clôture de purge égale au swing ;
- pivot interne source antérieur ou égal à la purge ;
- cible externe balayée avant confirmation du pivot interne ;
- MSS interne avant cible externe, par mèche seulement ou sans vrai croisement ;
- FVG dont la CE est dans la mauvaise moitié ;
- toucher de la FVG sans toucher sa CE lorsqu'elle sert de déclencheur ;
- EMA hors discount/premium ;
- OTE en dehors de 62–79 % ;
- sortie de fenêtre ou tentative de report à la fenêtre suivante ;
- réutilisation d'une liquidité consommée ;
- prix théorique jamais traité ;
- dépassement des limites de risque ou d'exposition.

## 13. Décisions de la révision du 9 août 2026

1. stacking obligatoire : D1 + H1 + M5 + M1, tous en EMA10/EMA20 ;
2. purge : mèche stricte et clôture de réintégration stricte ;
3. MSS : vrai croisement clôturé d'un pivot interne 2/2 formé post-purge ;
4. cible externe et MSS interne : événements distincts, cible d'abord ;
5. FVG : validation par sa CE, pas par l'intégralité de la zone ;
6. entrée : uniquement au marché après bougie clôturée ;
7. fenêtres séparées et obligatoires : `[02:00,05:00)`, `[07:00,10:00)` et
   `[19:00,22:00)` New York ;
8. conservation : aucun passage d'une fenêtre à une autre ;
9. sorties : baseline 2 R / 50 % / 4 R / trailing 2 R, configurable et à
   valider empiriquement ;
10. horaire : clôture nominale de la bougie, conversion broker historique vers
    UTC puis New York avec DST applicable à cette date.

## 14. Validation attendue

La suite automatisée doit couvrir au minimum :

- les égalités et inégalités strictes du stack et de la purge ;
- les pivots internes 2/2 et leur chronologie post-purge ;
- la séparation cible externe / MSS interne et leur symétrie LONG/SHORT ;
- les vrais croisements, l'idempotence et la consommation des liquidités ;
- la CE sous, sur et au-delà de l'EQ, y compris une FVG traversant l'EQ ;
- le toucher réel de la CE, les bornes OTE et le retest EMA ;
- exactement 540 minutes quotidiennes admises ;
- les bornes 02:00/05:00, 07:00/10:00 et 19:00/22:00 ;
- la transition DST US et la conversion historique du broker ;
- l'invalidation lors d'un changement d'instance de fenêtre ou d'un trou de
  cotations ;
- la parité de l'EA et de l'indicateur avec le moteur partagé ;
- la réconciliation d'une réponse broker incertaine et d'un fill TP1 partiel ;
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
