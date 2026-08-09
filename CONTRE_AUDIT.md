# Contre-audit complet de la solution ICT MQL5

- Date : 9 août 2026
- Révision auditée : `9178b72` (`Delete OTE`)
- Document précédent : `AUDIT.md`, conservé comme audit historique antérieur à la suppression
- Fichier supprimé : `ICT_Structure_OTE_EA.mq5` (434 lignes)

> **Statut du document : archive de la révision `9178b72`.** Depuis ce
> contre-audit, Silver Bullet a été remplacé par la v2 décrite dans
> `LOGIQUE_ENTREES.md` : moteur partagé, horloge historique explicite, gestion
> des sorties à chaque tick, fill/risque réconciliés, registre persistant et
> reprise bloquée en présence d'une position non reconstructible. Les constats
> visant les autres composants, notamment `TA_RiskManager.mq5`, n'ont pas été
> corrigés ni ré-audités dans ce chantier. La compilation et les tests v2 ne
> constituent pas une homologation live ; voir `README.md`, section 4.7.

## 1. Verdict exécutif

La suppression de `ICT_Structure_OTE_EA.mq5` retire bien du périmètre plusieurs défauts relevés dans le premier audit. Elle ne rend cependant pas la solution apte au live autonome.

Le dépôt courant contient quatre programmes MQL5, soit 3 779 lignes :

- deux EA : `ICT_SilverBullet_Strategy.mq5` et `TA_RiskManager.mq5` ;
- deux indicateurs : `ICT_SilverBullet_Signals.mq5` et `ICT_TopDown_Confluence.mq5`.

Quatre blocages principaux restent incompatibles avec un déploiement autonome :

1. les coupe-circuits du Risk Manager ne suppriment pas les ordres en attente et ne vérifient pas que le compte est réellement flat ;
2. l'horloge Silver Bullet est potentiellement fausse dans le Strategy Tester, ce qui fragilise directement les résultats obtenus avec les killzones ;
3. TP1, break-even et trailing Silver Bullet sont traités au premier tick de la bougie suivante, et non au prix où la cible a été touchée ;
4. Silver Bullet ne reconstruit aucun état après redémarrage : les anciennes positions ne sont plus gérées et la limite de positions peut être dépassée.

La suppression a également laissé le dépôt incohérent : README, rapports, dashboard et configurations continuent de présenter un EA absent comme compilé, backtestable ou en forward test.

Conclusion : **prototype avancé de recherche et de forward test, non validé pour le live autonome**.

## 2. Évaluation synthétique

| Domaine | État courant | Évolution depuis l'audit initial |
|---|---|---|
| Couverture fonctionnelle | Bonne | Stable sur les quatre composants restants |
| Cohérence du dépôt | Faible | Dégradée par la suppression incomplète |
| Fidélité stratégie/backtest/live | Faible | Nouveaux défauts importants identifiés |
| Exécution broker | Faible | Risques précédents confirmés |
| Protection du capital | Faible | Coupe-circuit toujours incomplet |
| Résilience aux redémarrages | Faible | Silver Bullet toujours non reconstructible |
| Reproductibilité | Faible | Presets présents, mais incomplets et sans preuves brutes |
| Performance des indicateurs | Moyenne à faible | Recalculs inutiles confirmés |
| Sécurité informatique | Correcte avec réserves | Pas de réseau ni secret ; dépendance DLL locale |
| Aptitude au live autonome | Insuffisante | Inchangée |

## 3. Périmètre et méthode

Le contre-audit couvre :

- les quatre sources `.mq5` encore présentes ;
- `README.md`, `REPORTS.md`, `dashboard.html` et `AUDIT.md` ;
- les presets `.set`, les configurations `.ini` et les fiches de réglages ;
- l'historique Git jusqu'au commit `9178b72` ;
- la cohérence entre fonctionnalités annoncées, code, paramètres et artefacts de validation.

Contrôles réalisés :

- lecture statique complète et contre-lecture indépendante par composant ;
- recherche des opérations de trading, états persistés, chemins documentés et artefacts orphelins ;
- comparaison des inputs de l'EA Silver Bullet avec les trois presets fournis ;
- vérification des hypothèses sensibles avec la documentation officielle MQL5.

Limites :

- aucun MetaEditor ni environnement Wine/MT5 n'est disponible dans l'environnement d'audit ;
- aucune compilation n'a donc été rejouée ;
- aucun backtest, test en vrais ticks, test de rejet broker ou test de redémarrage n'a été exécuté ;
- les affirmations « 0 erreur / 0 warning », les 486 optimisations et les résultats IS/OOS ne sont pas vérifiables à partir des artefacts versionnés.

Il s'agit donc d'un audit statique approfondi, pas d'une homologation d'exécution.

## 4. Inventaire fonctionnel courant

| Composant | Fonctionnalités principales | État |
|---|---|---|
| `ICT_TopDown_Confluence.mq5` | biais EMA multi-timeframes, structure interne/majeure, BOS/CHoCH/MSS, OTE, liquidités, EQH/EQL, NDOG, Asian Box, killzones, macros, dashboard | Riche, mais historique et horaires non fiables dans plusieurs cas |
| `ICT_SilverBullet_Strategy.mq5` | détection de sweep, alignement EMA, MSS, entrées FVG/OTE/EMA, sizing, TP partiel, BE, runner, risque dynamique, limite journalière | Fonctionnellement complet, mais exécution et reprise non sûres |
| `ICT_SilverBullet_Signals.mq5` | même moteur de signaux sans passage d'ordre, EMA, triangles, SL/TP visuels, killzones, macros, dashboard et alertes | Utilisable comme aide, avec divergences et coût de recalcul |
| `TA_RiskManager.mq5` | panneau d'ordres, sizing ATR/risque, pending, TP partiels, BE/trailing, scaling-in, limites d'équité, journal CSV et dashboard HTML | Prototype avancé ; garanties de protection insuffisantes |
| `sets/` et documentation | presets, configurations de test, résultats et procédures | Mélange d'artefacts actifs, historiques et orphelins |

## 5. Ce que la suppression a réellement corrigé

Les constats suivants de `AUDIT.md` ne s'appliquent plus au HEAD courant parce que leur code a été supprimé :

- fermeture ou modification de la mauvaise position par symbole en compte hedging ;
- perte de `g_posR` après redémarrage de Structure OTE ;
- forçage du lot minimum dans Structure OTE ;
- test incomplet de l'intersection de sa zone OTE ;
- incohérence `CopyBuffer` de son biais D1 ;
- grade A+ figé au moment de l'armement ;
- écrasement de son fichier `ict_bt_stats.txt`.

Ces défauts sont **retirés par suppression**, pas corrigés dans une version maintenue de l'EA. Ils restent pertinents uniquement si un ancien `.mq5` ou `.ex5` est remis en service depuis l'historique ou depuis un terminal MT5.

## 6. Corrections apportées au premier audit

Le contre-audit invalide ou nuance plusieurs affirmations de `AUDIT.md` :

1. **Les presets DE30 et XAUUSD existent.** Ils sont présents dans `sets/sets(ICT SB Signaux)/`. Le script `scratchpad/scan_markets.sh`, les `.ini` Silver Bullet complets et les rapports bruts restent en revanche absents.
2. **Le dépôt ne contient pas un seul commit.** Il en contient quatre au moment du contre-audit ; cette affirmation était déjà fausse lors de la création du premier audit.
3. **L'absence d'`ArraySetAsSeries(..., false)` n'établit pas à elle seule un parcours inversé.** Le sens implicite utilisé actuellement est compatible avec le parcours, mais il devrait être fixé explicitement pour la robustesse.
4. **L'absence d'`IndicatorRelease()` n'est pas une panne démontrée.** C'est une mesure d'hygiène à faible priorité, MT5 libérant normalement les ressources au déchargement.
5. **Le Risk Manager refuse correctement un lot auto sous le minimum.** Le forçage dangereux du minimum concerne Silver Bullet, pas le Risk Manager.
6. **Les défauts FVG et OTE de Silver Bullet sont dormants dans les presets DE30/XAU actuels**, qui fixent `InpUseFVG=false` et `InpUseOTE=false`. La FVG reste toutefois active dans les valeurs par défaut et dans la fiche MGC ; l'OTE redevient affecté dès qu'il est activé.

## 7. Blocages critiques — P0

### P0-1 — Le coupe-circuit du Risk Manager ne rend pas le compte flat

`CloseAllPositions()` ne parcourt que les positions (`TA_RiskManager.mq5:293-300`). Il ne supprime aucun ordre pending.

Les drapeaux `dayFlatDone` et `ddFlatDone` sont positionnés avant la tentative de fermeture (`:857-869`). Les résultats serveur ne sont pas contrôlés et aucune boucle ne vérifie ensuite l'état réel du compte.

Scénarios dangereux :

- un ordre en attente survit à la limite puis ouvre une nouvelle position ;
- une fermeture rejetée n'est pas retraitée ;
- une position ouverte par un autre EA après le premier flat reste active ;
- le message « positions fermées » peut être faux.

Correction requise :

1. choisir explicitement entre un verrou souple limité au composant et une conformité account-wide dure ;
2. en mode dur, interdire les émetteurs d'ordres et supprimer tous les pendings du compte avec `OrderDelete()`, quels que soient symbole et magic ;
3. fermer toutes les positions du compte ;
4. contrôler `ResultRetcode()` pour chaque demande ;
5. rescanner compte et ordres en continu tant que la limite reste active ;
6. ne positionner un état « flat confirmé » qu'après confirmation ; en mode souple, ne jamais présenter la limite comme garantie.

Références : [CTrade](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade), [OrderDelete](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradeorderdelete).

### P0-2 — Les killzones Silver Bullet peuvent être fausses en backtest

`NYNow()` traite `TimeGMT()` comme l'UTC réel (`ICT_SilverBullet_Strategy.mq5:199-204`). Cette heure décide du reset journalier et de l'admission dans les fenêtres (`:428-433`, `:502`).

Dans le Strategy Tester, MT5 simule `TimeGMT()`, `TimeTradeServer()` et l'heure locale avec la même heure serveur. Si les données broker sont GMT+2 ou GMT+3, la fenêtre New York testée est donc décalée de deux ou trois heures.

Les presets DE30 et XAUUSD activent `InpUseSbWindows=true`. Le défaut touche ainsi directement les résultats présentés comme validés OOS, et pas seulement une option inutilisée.

Le dépôt ne versionne toutefois pas l'offset exact des données utilisées. Le décalage de deux ou trois heures est très probable au vu du broker et des indications du README, mais son amplitude historique doit être confirmée à partir des timestamps de test.

Correction requise : utiliser une conversion explicite et testable depuis le timestamp broker, avec une table d'offset broker/DST applicable à chaque date historique. Rejouer ensuite l'intégralité des campagnes IS/OOS.

Référence : [simulation du temps dans le Strategy Tester](https://www.mql5.com/en/docs/runtime/testing).

### P0-3 — TP1, BE et trailing Silver Bullet ne s'exécutent pas au niveau annoncé

`OnTick()` retourne tant qu'une nouvelle bougie n'est pas ouverte (`ICT_SilverBullet_Strategy.mq5:407-413`). La gestion de position se trouve après ce verrou (`:550-598`).

Le programme :

1. observe après coup que le high ou le low de la bougie précédente a touché TP1 ;
2. envoie une clôture partielle au marché au premier tick de la bougie suivante ;
3. tente ensuite le break-even et le trailing.

Le prix peut avoir fortement reflué. Le core peut être fermé sous le niveau prévu, le BE peut être refusé, ou le SL broker peut avoir fermé toute la position dans la même bougie. Un backtest en vrais ticks ne corrige pas cette logique puisque le code refuse volontairement de gérer la position intrabar.

En outre, `coreTaken`, `beDone` et `runStop` avancent sans vérifier le succès serveur (`:569-596`).

Correction requise : séparer le moteur de signal sur bougie fermée du moteur de gestion appelé à chaque tick, ou placer les sorties protectrices chez le broker.

### P0-4 — Le redémarrage peut abandonner et multiplier les positions Silver Bullet

`OnInit()` ne reconstruit ni setups, ni tickets, ni niveaux, ni risque (`ICT_SilverBullet_Strategy.mq5:142-171`). `OpenTradeCount()` ne compte que les positions rattachées au tableau mémoire `g_setups` (`:263-268`).

Après un redémarrage avec trois positions ouvertes :

- leurs protections broker existantes restent figées ; un runner passé au BE peut déjà ne plus avoir de TP final ;
- leur TP1, BE et trailing ne sont plus gérés ;
- le compteur interne revient à zéro ;
- l'EA peut ouvrir trois nouvelles positions ;
- le niveau de risque dynamique et le verrou journalier repartent de leur état initial.

Des redémarrages répétés peuvent ainsi dépasser sans borne pratique `InpMaxPositions`.

Correction requise : reconstruire une machine d'état persistante depuis magic, symbole, commentaires, tickets réels, historique et variables globales ; compter également les positions broker correspondantes indépendamment de l'état mémoire.

## 8. Risques élevés — P1

### P1-1 — Les résultats serveur de trading ne sont pas validés

Le défaut est transversal aux deux EA.

Exemples Silver Bullet :

- ouverture : `ICT_SilverBullet_Strategy.mq5:361-381` ;
- partiel et BE : `:569-578` ;
- trailing : `:588-596`.

Exemples Risk Manager :

- fermeture : `TA_RiskManager.mq5:298` ;
- ordres : `:407-414` ;
- partiels : `:909-914` ;
- consolidation/BE/trailing : `:994`, `:1013`, `:1019`, `:1146-1153` ;
- déplacement de pending : `:1087-1115`.

Le booléen de `CTrade` ne suffit pas à confirmer l'exécution serveur. L'état local peut donc annoncer une ouverture, une sortie ou une modification non réalisée.

Correction : centraliser toutes les opérations dans un adaptateur vérifiant retcode, deal/order/ticket, prix exécuté, volume exécuté et état broker après requête.

### P1-2 — Silver Bullet calcule le risque depuis un prix théorique, pas depuis le fill

Le signal calcule `entry`, SL, R, TP1, TP final et volume depuis la bougie ou le modèle (`ICT_SilverBullet_Strategy.mq5:323-360`, `:504-544`). L'ordre est ensuite envoyé au marché avec `price=0` (`:363-364`).

Le fill réel peut différer du close EMA, de l'OTE ou de la borne FVG. Les objectifs, le risque journalisé et le lot ne représentent alors plus le trade exécuté.

Avec les presets actuels, seul le retest EMA est actif : le problème est moins extrême qu'avec un prix OTE/FVG entièrement théorique, mais un gap et le spread entre deux bougies suffisent à créer l'écart.

Correction : calculer le lot avant envoi depuis l'Ask/Bid réellement exécutable, avec une tolérance maximale de slippage. Après le fill, contrôler `ResultPrice()` et `ResultVolume()`, recalculer le plan et réduire ou refuser explicitement toute exposition excédentaire.

### P1-3 — Le sizing peut dépasser le risque demandé

Silver Bullet force toujours le volume au minimum broker (`ICT_SilverBullet_Strategy.mq5:232-241`, `:339-343`). Sur un petit compte, un SL large ou un symbole volatil, le risque réel peut dépasser `InpRiskPct`.

Autres fragilités :

- utilisation de `SYMBOL_TRADE_TICK_VALUE` au lieu d'un calcul de perte robuste (`:333-340`) ;
- prix normalisés aux décimales, pas à la grille `SYMBOL_TRADE_TICK_SIZE` (`:359-360`, `:573-596`) ;
- le Risk Manager refuse correctement un lot auto sous le minimum, mais son calcul reste exposé au tick value, au fill/slippage, au lot fixe et à la grille de prix (`TA_RiskManager.mq5:177-237`, `:353-413`).

Correction : refuser le trade si le lot minimum dépasse le budget, utiliser `OrderCalcProfit()` et aligner tous les prix sur la grille de tick.

### P1-4 — La limite journalière Silver Bullet n'est pas une limite de compte

`g_dayRealized`, `g_dayLocked` et `g_riskLevel` sont locaux à chaque instance (`ICT_SilverBullet_Strategy.mq5:132-135`). Le PnL n'est ajouté qu'à la clôture complète d'un setup suivi (`:292-315`).

Avec DE30 et XAUUSD simultanément :

- chaque graphique possède son propre seuil, mais ce seuil n'est pas un cap garanti : il n'aplatit pas les positions restantes et n'est constaté qu'après clôture complète ;
- chacun peut ouvrir jusqu'à trois positions ;
- les pertes flottantes, les trades externes et les positions perdues après redémarrage sont ignorés ;
- avec `InpUseAccountEquity=true`, la limite monétaire suit l'équité courante ; avec les presets DE30/XAU, elle repose au contraire sur le montant fixe `InpAccountSize=50000`. Aucun des deux modes ne constitue une équité de début de journée figée.

Le Risk Manager et Silver Bullet utilisent en plus des définitions différentes de la journée. Une seule autorité de risque account-wide est nécessaire.

### P1-5 — Le Risk Manager n'a pas d'architecture multi-instance sûre

La gestion de position est liée à `_Symbol` (`TA_RiskManager.mq5:890-891`, `:941-942`), ce qui pousse à poser plusieurs instances sur plusieurs graphiques. Mais chaque instance :

- reçoit les transactions de tout le compte (`:1342-1413`) ;
- écrit dans le même `TA_Journal.csv` (`:479-492`) ;
- incrémente les mêmes statistiques globales (`:1391-1395`) ;
- partage le même namespace par compte (`:1241`) ;
- ne possède ni leader, ni verrou, ni dédoublonnage par deal.

Résultats possibles : journaux dupliqués ou perdus, statistiques multipliées, alertes répétées et courses sur les états persistés.

Correction : une instance account-wide unique, ou une séparation explicite entre un service de compte singleton et des panneaux par symbole.

### P1-6 — Les TP partiels du Risk Manager ne sont pas des ordres protecteurs

Ils sont sondés une fois par seconde par timer et sur la quote courante (`TA_RiskManager.mq5:884-915`, `:1252`, `:1262`).

Une cible touchée puis quittée entre deux timers peut être manquée. Plusieurs niveaux traversés ne produisent qu'une sortie par passage. Une panne ou fermeture du terminal désactive toutes les cibles intermédiaires, malgré la persistance du plan.

La documentation doit les présenter comme une automation locale best-effort, ou l'architecture doit placer des ordres broker adaptés.

Si les sorties multiples font partie du comportement exigé pour le forward, ce constat devient lui-même bloquant avant le test.

### P1-7 — Déplacement des pendings et scaling-in désynchronisent le plan

Le drag d'un pending déplace entrée, SL et TP final (`TA_RiskManager.mq5:1067-1103`), mais pas les prix de TP partiels persistés par `PlanSet()` (`:310-317`, `:418-428`). Après exécution, les sorties intermédiaires peuvent donc être immédiatement déclenchées ou se trouver au mauvais R.

Le déplacement applique aussi le même delta à tous les pendings du symbole et du magic sans distinguer groupe, direction ou prix initial (`:1090-1100`).

Un remplissage partiel ajoute un autre cas non géré : la position partiellement servie et le reliquat du pending peuvent coexister alors que le plan a été calculé sur le volume total. La première clôture peut supprimer ce plan avant que le reliquat ne soit exécuté, en particulier sur des symboles Exchange utilisant un mode de remplissage partiel.

Dans `ManageGroup()` :

- le premier SL connu devient arbitrairement le SL de référence (`:964-976`) ;
- il est appliqué sans vérifier son côté pour chaque position (`:980-995`) ;
- l'exposition n'est pas recalculée après un élargissement ;
- les plans partiels ne sont pas réancrés ;
- une modification échouée peut malgré tout faire mémoriser le ticket comme consolidé (`:1024-1038`) ;
- le BE du même cycle peut restaurer l'ancien TP capturé avant consolidation (`:935-948`, `:1000-1019`).

### P1-8 — Le cap d'exposition sous-estime le risque

`OpenRiskCash()` ignore les positions sans SL (`TA_RiskManager.mq5:243-259`) et tous les ordres pending. Plusieurs pendings peuvent donc être acceptés séparément puis dépasser le cap lorsqu'ils se déclenchent.

Une position sans SL devrait bloquer les nouvelles entrées ou être comptée comme risque non borné. Les pendings doivent être intégrés avec leur volume et leur SL projeté.

### P1-9 — Le journal du Risk Manager peut manquer ou doubler des clôtures

Le handler récupère `DEAL_POSITION_ID`, puis l'utilise comme ticket dans `PositionSelectByTicket()` (`TA_RiskManager.mq5:1350-1356`). Or identifiant et ticket n'ont pas la même garantie de stabilité.

L'ordre d'arrivée des transactions n'est pas garanti. Il existe donc un risque de séquencement à confirmer par test : si le ticket semble encore vivant lors du deal final, le handler retourne sans mécanisme de recontrôle. À l'inverse, un changement de ticket peut faire prendre une sortie partielle pour une clôture complète, supprimer le plan et mettre à jour le streak trop tôt.

Le handler effectue aussi un traitement lourd : agrégation de l'historique, écriture/relecture du CSV et régénération HTML (`:1363-1412`, `:479-545`). La file des transactions MQL5 est limitée ; un `CLOSE ALL` volumineux augmente le risque de retard ou d'éviction.

Références : [OnTradeTransaction](https://www.mql5.com/en/docs/event_handlers/ontradetransaction), [propriétés des positions](https://www.mql5.com/en/docs/constants/tradingconstants/positionproperties).

### P1-10 — Les métriques de risque du Risk Manager ne sont pas fiables dans la durée

Le registre initial est limité à 200 positions et n'est jamais purgé (`TA_RiskManager.mq5:112-116`, `:437-468`). Il n'est pas persisté.

Cas incorrects :

- trade très court ouvert et fermé avant le timer : R nul ;
- redémarrage après partiel ou BE : risque reconstruit depuis l'état actuel ;
- lot fixe : pourcentage mémorisé depuis le panneau, pas depuis le risque réel ;
- grade changé avant clôture : le journal prend le grade courant (`:1408`) ;
- frais `DEAL_FEE` omis ;
- prix forcés à cinq décimales et volumes à deux.

Le grade, le risque monétaire initial, le volume initial et la politique de risque doivent être capturés à l'entrée et persistés par `POSITION_IDENTIFIER`.

### P1-11 — Les limites d'équité confondent PnL et flux de capital

`dayEq` et `peak` ne distinguent pas profit/perte, dépôt et retrait (`TA_RiskManager.mq5:820-845`). La garde ne réinitialise qu'au-delà de ×3 ou en dessous de ×0,3 (`:835-840`).

Un retrait ordinaire peut donc provoquer une fausse perte journalière ou un faux drawdown, puis `CLOSE ALL`. Inversement, le `peak` inclut les gains flottants et transforme la limite maximale en trailing drawdown depuis le plus haut d'équité, ce qui ne correspond pas nécessairement à la règle « FTMO-like » annoncée.

La politique exacte doit être définie, nommée correctement et testée avec dépôts, retraits, crédits et PnL flottant.

### P1-12 — Les modèles FVG et OTE contiennent des prix asymétriques ou inexistants

FVG baissière : quand `h2 < l4`, le code stocke `fvgTop=h2` et `fvgBot=l4` (`ICT_SilverBullet_Strategy.mq5:457-462`, Signals `:685-689`). Le test short exige ensuite de traverser tout le gap (`Strategy:513-514`, Signals `:734-735`), contrairement au comportement long.

OTE : une simple touche de 62 % peut produire une entrée théorique au sweet spot 70,5 %, même si ce prix n'a jamais été atteint (`Strategy:516-534`, Signals `:737-751`). `InpOteHigh=0.79` n'est jamais utilisé dans l'EA.

Les presets DE30/XAU désactivent FVG et OTE. Ces défauts sont donc dormants pour ces deux configurations, mais ils affectent les valeurs par défaut, les autres usages et la fiche MGC qui active FVG.

### P1-13 — Le modèle EMA actif ne garantit pas discount/premium

La documentation décrit un retracement dans le discount/premium avant une entrée FVG, OTE ou EMA (`README.md:154`, fiche des sets `README.md:3`). Le déclencheur EMA ne teste pourtant jamais le midpoint de la jambe (`ICT_SilverBullet_Strategy.mq5:536-541`, Signals `:754-758`).

DE30 et XAU désactivent FVG et OTE : leur seul modèle d'entrée est précisément ce retest EMA non borné. Les configurations présentées comme validées ne correspondent donc pas strictement au modèle décrit.

### P1-14 — Les mêmes liquidités et MSS peuvent être réutilisés

`AlreadySwept()` ne consulte que les setups actuellement en mémoire (`ICT_SilverBullet_Strategy.mq5:277-282`, Signals `:275-280`). Une fois un setup supprimé, le niveau n'est plus mémorisé comme consommé et peut immédiatement créer un nouveau setup.

Par ailleurs, `g_mssBar` est rafraîchi à chaque clôture qui reste au-delà du même swing (`Strategy:451-455`, Signals `:680-683`). `InpMssLookback` ne mesure donc pas toujours l'âge de la cassure initiale.

### P1-15 — Le compte hedging requis n'est jamais validé

Silver Bullet et le Risk Manager utilisent `PositionClosePartial`, mais aucun `OnInit()` ne vérifie `ACCOUNT_MARGIN_MODE` (`ICT_SilverBullet_Strategy.mq5:142-171`, `TA_RiskManager.mq5:1239-1254`).

En netting, les positions fusionnent, le mapping setup/plan vers position devient invalide et les reversals `DEAL_ENTRY_INOUT` ne sont pas correctement traités.

Correction : refuser explicitement le netting tant qu'une branche dédiée n'existe pas.

### P1-16 — Silver Bullet confond l'identifiant de position et son ticket

Après l'ouverture, Silver Bullet stocke `DEAL_POSITION_ID` (`ICT_SilverBullet_Strategy.mq5:371-375`), puis l'utilise comme ticket dans `PositionSelectByTicket`, `PositionClosePartial` et `PositionModify` (`:267`, `:551`, `:569-576`, `:588-595`).

L'identifiant suit la position pendant tout son cycle de vie, tandis que son ticket peut changer après certaines opérations serveur. Une position toujours ouverte peut alors être considérée comme fermée, classée dans le PnL et abandonnée par le gestionnaire.

Correction : persister l'identifiant comme clé métier, mais résoudre et vérifier le ticket courant avant chaque opération.

### P1-17 — Un volume indivisible désactive BE et trailing Silver Bullet

Quand le volume est trop petit pour permettre une clôture partielle, `coreLots=0` et `coreTaken=true` (`ICT_SilverBullet_Strategy.mq5:345-353`, `:380`). Or `beDone` n'est activé que dans le bloc `!coreTaken` (`:563-581`) et le trailing exige ensuite `beDone`.

La position censée devenir « tout runner » reste donc au TP fixe final. Sur les petits comptes et symboles à volume minimum élevé, cela change directement la stratégie backtestée et mérite une correction avant validation.

### P1-18 — TopDown peut conserver des cassures intrabar disparues à la clôture

Les trois constats TopDown suivants sont classés P1 pour leur impact potentiel sur une décision discrétionnaire et la fidélité des grades, même si cet indicateur ne passe aucun ordre lui-même.

`OnCalculate()` traite la bougie en formation jusqu'à `rates_total-1` et la réexécute à chaque tick (`ICT_TopDown_Confluence.mq5:723-745`). Les pivots et cassures modifient immédiatement les états globaux (`:747-822`).

Si le prix franchit un niveau puis réintègre avant la clôture, les drapeaux de cassure, la tendance et les objets ne sont pas annulés. Un rechargement peut ensuite produire un historique différent.

Correction : calculer les événements structurels sur bougie clôturée, ou rendre l'état intrabar explicitement provisoire et réversible.

### P1-19 — Les anciens OTE TopDown sont gradés avec le biais actuel

`DrawOte()` reçoit un index historique, mais appelle `StackState()` sans date (`ICT_TopDown_Confluence.mq5:876-890`). `StackState()` part du shift zéro courant (`:307-321`).

Tous les anciens OTE sont donc reclassés A+ avec le biais du moment du chargement. Deux chargements à des dates différentes peuvent modifier rétroactivement les labels historiques.

### P1-20 — Les objets historiques TopDown utilisent une conversion horaire instable

`gmtOff` est l'offset serveur actuel (`ICT_TopDown_Confluence.mq5:643`, `:717`) et est appliqué aux dates historiques (`:190-199`). Un historique couvrant les changements GMT+2/GMT+3 peut être décalé d'une heure selon la saison au moment du chargement.

`InpKzDays` compare en plus des nombres `YYYYMMDD` et ajoute arbitrairement 20 (`:832-848`). Par exemple, le 31 juillet et le 1er août donnent une différence numérique de 70 alors qu'ils sont consécutifs. Le nombre de jours affichés est donc faux autour des changements de mois et d'année.

Les objets vieillissants ne sont pas systématiquement supprimés pendant une session longue ; cette sélection erronée peut donc aussi laisser s'accumuler des killzones et macros hors de la fenêtre attendue.

## 9. Risques moyens — P2

### 9.1 Silver Bullet Strategy

- **Commission d'entrée ignorée.** `FinalizeSetup()` exclut les deals d'entrée avant d'additionner leurs commissions (`:296-307`). Un trade perdant après frais peut être classé gagnant.
- **Biais non reconstruit.** Les biais commencent à zéro et `StackBias()` ne regarde que la dernière bougie fermée (`:244-253`). Un démarrage en zone EMA neutre peut diverger de l'indicateur, qui reconstruit l'historique.
- **Horaires EA/indicateur différents aux frontières.** L'EA teste l'heure au début de la nouvelle bougie ; Signals utilise l'heure d'ouverture de la bougie signal. Une barre 02:55–03:00 peut être acceptée par l'un et refusée par l'autre.
- **Exports non uniques.** Le nom CSV d'`OnTester()` omet timeframe, dates, broker et plusieurs inputs (`:636-649`). Un IS et un OOS peuvent écraser le même fichier.

### 9.2 Silver Bullet Signals

- **Historique reparcouru à chaque tick.** Après le premier calcul, la boucle recommence à l'index 6 (`ICT_SilverBullet_Signals.mq5:650-653`) et parcourt presque tout l'historique même si les barres sont sautées.
- **Lanes recréées à chaque calcul.** `RebuildLanes()` supprime et recrée les killzones/macros à chaque `OnCalculate()` (`:795`), avec charge CPU et risque de clignotement.
- **Offset broker figé.** Il n'est détecté qu'à l'initialisation (`:150`, `:180`). Un changement DST serveur pendant une longue session nécessite un rechargement ou une valeur manuelle.
- **Handles HTF pas tous validés.** `OnInit()` ne valide qu'une partie des handles (`:146-148`). Si les buffers HTF ne sont pas prêts, une barre peut être marquée traitée et ne jamais être recalculée (`:248-258`, `:650-654`).
- **Reset historique incomplet.** Quand `prev_calculated` revient à zéro, setups, `g_lastProcTime` et objets ne sont pas tous reconstruits depuis un état propre.
- **Bouton de fermeture ambigu.** Le bouton `x` masque le dashboard mais ne retire pas l'indicateur, contrairement à la description du README.

### 9.3 TopDown

- **Pivot OTE potentiellement antérieur au break.** Le break n'est pas horodaté et le premier pivot confirmé ensuite peut s'être formé avant lui (`:758-787`).
- **Biais HTF intrabar.** `StackState()` utilise la bougie HTF en formation (`:307-321`) ; le dashboard peut changer plusieurs fois avant clôture.
- **Handles insuffisamment validés.** Huit handles sont créés sans validation complète (`:624-634`). Un biais nul temporaire peut produire un grade qui n'est pas repris ensuite.
- **Liquidité majeure dessinée comme interne.** Un niveau déjà connu est promu par un booléen sans mettre à jour le style de sa ligne (`:329-337`). La tolérance dite en ticks utilise `_Point`, pas le tick size.
- **Collisions entre instances.** Le préfixe fixe `ICTTD_` est partagé (`:128`) ; deux instances sur le même graphique peuvent supprimer ou modifier les objets l'une de l'autre (`:639`, `:727`).
- **État du scroll non restauré.** Une désinitialisation pendant un drag peut laisser `CHART_MOUSE_SCROLL=false`.

### 9.4 Risk Manager

- **Aucune validation complète des inputs et capacités broker** dans `OnInit()` (`:1239-1254`) : seuils, ordre des paliers, RR, ATR, volumes, freeze/stops level, filling mode et permissions.
- **Mode réduit non neutre.** Tous les champs ne sont pas sauvegardés et `EffRiskPct()` peut revenir à `InpRiskMan` quand le champ du panneau n'existe plus (`:162-175`, `:631-652`).
- **Dashboard non autonome.** Le template `TradeAssistant_Dashboard.html` annoncé n'est pas dans le dépôt. Un ancien `TA_View.html` peut être ouvert si la régénération échoue (`:541-551`).
- **Payload JavaScript non échappé** pour les chaînes du journal (`:533-536`).
- **Affichage et gestion n'ont pas toujours le même périmètre.** Le résumé inclut toutes les positions du symbole, tandis que BE, trailing et partiels filtrent le magic.
- **Devise affichée en `$`** même pour un compte dans une autre devise.
- **Namespace persistant fragile.** Le login `long` est converti en `int` et le serveur/broker n'entre pas dans la clé.
- **Réduction après objectif non verrouillée.** `targetDone` évite seulement de répéter l'alerte ; si l'équité repasse sous l'objectif, le facteur de risque revient à son niveau normal (`:846-850`).
- **Configuration multi-TP ambiguë.** Avec des RR explicites, le champ TP peut être ignoré et rien n'impose des niveaux strictement croissants (`:374-387`).
- **Volume fixe non normalisé.** Le lot manuel n'est pas systématiquement aligné sur minimum, maximum et pas de volume du symbole avant la demande broker.

### 9.5 Durcissement faible priorité

- fixer explicitement le sens des tableaux reçus par `OnCalculate()` ;
- libérer explicitement les handles restants dans `OnDeinit()` ;
- rendre les préfixes d'objets uniques par chart et sous-fenêtre ;
- valider et borner les coordonnées mémorisées des dashboards ;
- éviter de supprimer/recréer toutes les étiquettes chaque seconde.

## 10. Incohérences du dépôt après suppression

### 10.1 Documentation principale orpheline

`README.md` inventorie toujours `ICT_Structure_OTE_EA.mq5` (`README.md:5`) et lui consacre toute la section 1 (`:15-68`). Les commandes de backtest ne sont plus exécutables depuis le source courant.

`REPORTS.md` est entièrement consacré à l'EA supprimé : méthodologie, résultats, candidat portefeuille et forward « EN COURS » (`REPORTS.md:3-83`).

`dashboard.html` continue de présenter l'ancien « système complet », ses performances et le magic `260709` (`dashboard.html:130-245`). Il s'agit désormais d'une archive non étiquetée.

La suppression Git du source ne retire ni un ancien `.ex5` installé dans MT5, ni un EA déjà attaché à un graphique. Si le forward annoncé existe réellement, il peut continuer hors contrôle de version. Ce point externe n'est pas vérifiable dans le dépôt.

### 10.2 Artefacts Structure OTE orphelins

Les fichiers suivants ciblent encore l'EA absent :

- `sets/ICT_Structure_OTE_Aplus.set` ;
- `sets/backtest_US500_H1.ini` ;
- `sets/backtest_US500_M15.ini`.

Les deux `.ini` demandent `ICT_Structure_OTE_EA.ex5`. Sans ancien binaire, ils échouent ; avec un ancien binaire, ils exécutent un artefact non reproductible depuis le HEAD et sans provenance de build vérifiable. Le source reste récupérable dans l'historique Git.

### 10.3 `AUDIT.md` est historique, pas courant

Il annonce encore cinq programmes et 4 213 lignes, contient des constats propres au fichier supprimé et conclut sur ce composant. Il doit être clairement marqué comme audit pré-suppression ou remplacé dans les liens de référence par le présent document.

## 11. Reproductibilité et qualité des preuves

### 11.1 Presets Silver Bullet présents mais incomplets

Les 40 inputs actuels de l'EA ont été comparés aux presets : toutes les clés présentes sont valides, sans clé inconnue.

En revanche :

- DE30 et XAUUSD ne fixent que 15 inputs sur 40 ;
- FDXS n'en fixe que 10 sur 40 ;
- `InpTrailRunner`, timeframes, EMA, alignement, risque, max positions, DD, expiry, lookback MSS, DST, magic et slippage ne sont pas tous figés ;
- les presets ne sont donc pas des snapshots autonomes de l'expérience.

`InpUseAccountEquity=false` et `InpAccountSize=50000` créent aussi un risque opérationnel : un oubli du changement manuel demandé dans la fiche peut surdimensionner un petit compte live.

### 11.2 Procédure headless contradictoire

`README.md:167` explique que `ExpertParameters=.set` n'a pas chargé le preset dans les tests précédents. `README.md:204-206` recommande pourtant ensuite exactement cette méthode avec le preset FDXS obsolète.

Autres manques :

- aucun `.ini` Silver Bullet avec section `[TesterInputs]` ;
- aucun rapport MT5 brut ;
- aucun CSV des 486 optimisations ;
- aucune métadonnée de symbole, spread, commission, swap et qualité de ticks ;
- script `scratchpad/scan_markets.sh` absent ;
- chemin documenté `../sets(ICT SB Signaux)/...` différent du chemin réel.

### 11.3 Résultats OOS non acceptables comme preuve finale

Les chiffres ne peuvent pas être vérifiés depuis le dépôt. Deux défauts du moteur affectent directement leur interprétation : l'heure du Strategy Tester et la gestion des sorties à la bougie suivante.

Le dépôt ne permet pas de vérifier que la sélection des paramètres a été gelée avant consultation de l'OOS. Cette période a au minimum participé à la validation et à la décision de déploiement ; elle ne peut donc plus servir de holdout final aveugle. La documentation reconnaît à juste titre que le vrai test restant est le forward.

Les résultats doivent être rejoués après correction :

- avec `.ini` complets et versionnés ;
- en vrais ticks ;
- avec timezone broker vérifiée par date ;
- avec commissions, swaps et spread historiques ;
- sur une période de holdout jamais utilisée pour choisir les paramètres.

### 11.4 Documentation interne contradictoire

- `FDXS.md` décrit le futur Eurex/NinjaTrader M1, tandis que les fiches CFD/MT5 imposent M5 et classent le preset FDXS comme ancien baseline : le packaging mélange les contextes sans séparation suffisamment explicite ;
- `MGC.md` décrit une « opacité triangles » absente des inputs Signals ;
- le README dit que les lanes sont reconstruites sur nouvelle barre, alors que le code le fait à chaque calcul ;
- le champ `ExpertParameters` est à la fois dénoncé et recommandé ;
- versions TopDown `v2.5`, propriété `1.00`, rapport `v2.2` et dashboard Pine `v1.9` coexistent ;
- les assertions de parité TradingView/NinjaTrader et de compilation ne sont pas démontrables avec le dépôt seul.

## 12. Architecture et maintenabilité

### Points solides

- séparation claire entre indicateurs, stratégie et panneau de risque ;
- commentaires métier abondants ;
- utilisation de bougies fermées pour la majorité des signaux Silver Bullet ;
- magic numbers distincts ;
- calculs de volume prenant en compte tick size et tick value, même s'ils doivent être durcis ;
- persistance des plans de TP partiels du Risk Manager ;
- absence de secrets et d'appels réseau ;
- suppression du fichier traçable et récupérable via Git.

### Faiblesses structurelles

- quatre fichiers monolithiques et beaucoup d'état global mutable ;
- moteurs Silver Bullet EA/Signals dupliqués et déjà divergents ;
- plusieurs implémentations de New York/DST ;
- pas de service account-wide unique pour la protection du capital ;
- pas d'adaptateur d'exécution robuste ;
- pas de machine d'état persistante pour Silver Bullet ;
- dépendance implicite à des templates et sources hors dépôt ;
- aucune suite de tests ni pipeline de compilation.

Architecture cible :

```text
Time / Session Service
          |
          v
Shared Signal Engine ------> Indicator Exposer
          |
          v
Position Plan
          |
          v
Account Risk Authority
          |
          v
Execution Adapter <-------> Broker State Reconciliation
          |
          v
Persistent Trade State ----> Journal / Metrics
```

L'EA et l'indicateur Silver Bullet doivent utiliser le même moteur déterministe. Une seule autorité doit calculer le risque et les limites du compte.

## 13. Sécurité

Le risque dominant reste financier et opérationnel, pas une compromission réseau.

Points rassurants :

- aucun secret versionné ;
- aucun `WebRequest` ni accès réseau ;
- écritures limitées aux fichiers/variables du terminal ;
- magic numbers utilisés dans les opérations de gestion ciblées.

Réserves :

- `TA_RiskManager.mq5` importe `shell32.dll` pour ouvrir le dashboard ; toute l'installation exige donc l'autorisation DLL pour une fonction secondaire ;
- le template HTML externe manque ; un dashboard ancien peut être ouvert ;
- les chaînes CSV injectées en JavaScript ne sont pas échappées proprement ;
- `CLOSE ALL` est immédiat, sans confirmation, et ne ferme actuellement pas tout ;
- le verrou « souple » est contournable volontairement et ne constitue pas un contrôle de conformité.

## 14. Plan de remédiation

### Phase A — avant tout nouveau forward automatisé

1. Définir la politique du Risk Manager : soit conformité account-wide dure, soit verrou opérateur souple. En mode dur, rendre le flat permanent et idempotent : supprimer tous les pendings du compte, fermer les positions, vérifier les retcodes et rescanner tant que la limite est active.
2. Séparer gestion intrabar et génération de signaux Silver Bullet ; exécuter ou protéger TP1/BE/trailing au bon moment.
3. Corriger l'horloge du Strategy Tester avec une conversion broker/UTC/NY historique testable.
4. Reconstruire toutes les positions Silver Bullet au démarrage et compter les positions broker réelles.
5. Mettre en place un adaptateur commun contrôlant chaque réponse serveur.
6. Décider d'une architecture Risk Manager singleton avant toute utilisation multi-symbole.

### Phase B — avant de faire confiance aux statistiques

1. Recalculer le plan Silver Bullet depuis le fill réel et refuser tout dépassement de risque au lot minimum.
2. Corriger la FVG short, l'intersection OTE, la borne 79 %, la consommation des sweeps et l'âge du MSS.
3. Appliquer réellement la contrainte discount/premium ou corriger la documentation du modèle EMA.
4. Refuser les comptes netting tant qu'ils ne sont pas supportés.
5. Persister risque, grade, volume, position identifier et état des sorties dès l'entrée.
6. Réancrer atomiquement tous les SL, TP finaux et TP partiels lors d'un drag ou scaling-in.
7. Rejouer IS/OOS et holdout en vrais ticks avec artefacts complets versionnés.

### Phase C — fidélité des indicateurs et robustesse

1. Calculer la structure TopDown sur clôture ou gérer un état provisoire réversible.
2. Calculer chaque grade A+ avec le biais de sa date historique.
3. Remplacer les opérations sur `YYYYMMDD` par de vrais `datetime` et gérer l'offset broker par date.
4. Empêcher un pivot antérieur au break de terminer un OTE.
5. Optimiser `OnCalculate()` de Signals et ne reconstruire les lanes que lorsque nécessaire.
6. Valider tous les handles et rejouer proprement l'historique après réinitialisation.
7. Ajouter une validation exhaustive des inputs et capacités broker dans chaque `OnInit()`.

### Phase D — nettoyage et industrialisation

1. Choisir pour les artefacts Structure OTE : suppression cohérente ou déplacement dans un dossier `archive/` clairement étiqueté.
2. Mettre à jour README, REPORTS, dashboard et liens afin qu'ils décrivent uniquement le HEAD courant.
3. Versionner les `.ini` complets, rapports bruts, logs de compilation et métadonnées broker.
4. Extraire les services communs dans des `.mqh` testables.
5. Ajouter compilation automatique, tests déterministes de temps/DST, tests de sizing et scénarios de reprise/rejet broker.

## 15. Critères d'acceptation recommandés

La solution ne devrait être requalifiée « candidate live » que lorsque les preuves suivantes existent :

- compte réellement flat après limite, y compris avec pendings et rejets simulés ;
- en mode conformité dure, toute nouvelle exposition est empêchée à la source ou immédiatement reflatée tant que la limite reste active ; en mode souple, cette limite est documentée comme non garantie ;
- reprise après redémarrage avec mêmes positions, TP1, BE, trailing, risque et compteur ;
- une seule ligne de journal et une seule mise à jour statistique par position, même avec plusieurs graphiques ;
- parité signal EA/indicateur sur un corpus horodaté ;
- tests DST hiver/été, changements de mois/année et broker GMT+2/GMT+3 ;
- en sizing automatique strict, volume réel ne dépassant jamais le budget configuré ; les modes lot fixe et override sont explicitement exclus de cette garantie ;
- niveaux valides sur des symboles dont le tick size diffère du point ;
- compilation propre reproductible ;
- backtests en vrais ticks reproductibles depuis des fichiers versionnés ;
- forward démo sans redémarrage caché, artefact binaire non versionné ou intervention manuelle non journalisée.

## 16. Conclusion

Le retrait de `ICT_Structure_OTE_EA.mq5` réduit la surface de code et supprime les risques propres à cet EA. Il révèle toutefois un dépôt partiellement supprimé plutôt qu'une solution nettoyée : les traces d'exploitation de l'ancien composant sont toujours actives dans la documentation et les configurations.

Le contre-audit confirme surtout que les risques principaux résident désormais dans Silver Bullet et le Risk Manager. Les sorties retardées, l'horloge de backtest, l'absence de reprise, les retcodes non contrôlés et le coupe-circuit incomplet empêchent de considérer les performances publiées comme une validation suffisante du comportement live.

`AUDIT.md` doit être lu comme l'état antérieur au commit `9178b72`. Le présent `CONTRE_AUDIT.md` est le document de référence produit pour cette révision auditée ; il reste à le versionner avec les éventuels nettoyages décidés.
