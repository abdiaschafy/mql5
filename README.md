# ICT — MQL5 (MetaTrader 5)

| Fichier | Type | Rôle |
|---|---|---|
| `ICT_Structure_OTE_EA.mq5` | **Source supprimé** (magic historique 260709) | Documentation et artefacts historiques seulement — section 1 |
| `ICT_TopDown_Confluence.mq5` | **Indicateur** | Port MT5 **complet** de l'indicateur v2.5 (TV/NT) — section 2 |
| `TA_RiskManager.mq5` | **EA panneau** (magic 260710) | **Risk Manager + trade manager** : portage MT5 du Trade Assistant NT — section 3 |
| `ICT_SilverBullet_Strategy.mq5` | **EA** (magic 260711) | Stratégie **Silver Bullet** (modèle continuation) — section 4 |
| `ICT_SilverBullet_Signals.mq5` | **Indicateur** | **Signaux Silver Bullet** (EMA10/20, triangles, killzones en bas, dashboard déplaçable) — section 4 |

> ⚠️ **Recharger un EA/indicateur MT5** : recompiler **ne suffit pas** (l'image reste en cache pour la session), et le re-glisser sur le graphique non plus → **redémarrer le terminal**. Les composants attachés au graphique peuvent se recharger, mais leur état en mémoire n'est pas nécessairement reconstruit ; voir notamment la sécurité de redémarrage Silver Bullet en section 4.4.

---

# 1. Ancien ICT Structure OTE EA — archive

> Le source `ICT_Structure_OTE_EA.mq5` a été supprimé à la révision
> `9178b72`. Cette section, les presets et les rapports associés décrivent
> uniquement l'ancien composant ; ils ne sont plus compilables ni reproductibles
> depuis l'état courant du dépôt.

Il s'agissait du portage MT5 de la stratégie Pine
`ICT_Structure_OTE_Strategy` (dossier `../pine/`), conçu comme un EA
symbol-agnostic pour US500 / US30 / USTEC / DE30.

- **Magic** : `260709`
- **Dernière compilation historique annoncée** : 0 erreur / 0 warning
- **Ancien emplacement** : `...\MetaQuotes\Terminal\<hash>\MQL5\Experts\`
- **Marché de référence** : US500 (équivalent du MES développé sur TradingView)

---

## Logique (identique à la stratégie Pine)

1. **Structure interne** — pivots `InpStructLen` (5) → état `trend` sur cassure en clôture d'un swing (BOS/CHoCH).
2. **OTE** — 1 par cassure, armée au **pic confirmé** (1er pivot opposé après le break). Origine (1.0) = corps du swing lanceur (verrouillé), terminus (0.0) = corps du pic. Fibs 0.62–0.79 (ancrage **corps**).
3. **Entrée** — tap de l'OTE (bougie fermée) pendant **killzone/macro Londres-NY** (heure NY via `TimeGMT()+InpNYGMTOffset`). **LONG + SHORT**.
4. **Filtre A+** — `InpUseD1Filter=true` (défaut) : ne trade que dans le sens du **biais D1** (EMA10/20). C'est le filtre qui fait l'edge.
5. **Sorties** — SL = mèche swing origine ∓ `InpSLBuffer` ; TP `InpTPR`(3)R ; break-even à `InpBER`(2)R.
6. **MM** — risque `InpRiskPct`(1 %) + échelle anti-DD (1 %→0,5 %→0,25 %) ; cap perte/jour ; flat 16:15 NY.

Architecture : structure/armement/entrée en **OnNewBar** ; break-even + flat en **OnTick**. `OnTester()` écrit les stats du backtest dans `Common\Files\ict_bt_stats.txt`.

## Inputs principaux

| Input | Défaut | Rôle |
|---|---|---|
| `InpStructLen` | 5 | Longueur pivots structure |
| `InpUseD1Filter` | **true** | Filtre A+ (aligné biais D1) |
| `InpUseKZ` | true | Restreindre aux killzones/macros |
| `InpNYGMTOffset` | −4 | Décalage GMT de New York (EDT=−4 / EST=−5) |
| `InpRiskPct` | 1.0 | Risque par trade (%) |
| `InpSLBuffer` / `InpBEBuffer` | 5.0 | Buffers SL / BE (unités de prix) |
| `InpTPR` / `InpBER` | 3 / 2 | TP et break-even en R |
| `InpMagic` | 260709 | Magic number |

## ⚠️ Points d'attention

- **`InpNYGMTOffset`** : à ajuster selon le fuseau serveur du broker (et le DST). Un offset faux décale les killzones. Le backtest H1 propre suggère que −4 est ~correct chez Exness ; vérifier en live.
- **`InpSLBuffer` / `InpBEBuffer`** en **unités de prix** du symbole (pour US500 : points d'indice).
- **Capital** : dimensionner le dépôt pour que le risque % donne un sizing sensé (voir `REPORTS.md`).

## Backtest headless historique (non reproductible sans restaurer le source)

Fermer MT5 (1 instance/dossier de données), puis :
```
terminal64.exe /config:sets\backtest_US500_H1.ini
```
(section `[Tester]`, `ShutdownTerminal=1`). Le rapport HTML `/config` ne s'écrit pas de façon fiable → les stats sont écrites par `OnTester()` dans `Common\Files\ict_bt_stats.txt`. Voir `REPORTS.md`.

## Résultats & réglages

- Résultats détaillés → **`REPORTS.md`**
- Presets `.set` + configs de test → **`sets/`**


---

# 2. Indicateur `ICT_TopDown_Confluence.mq5` (port complet v2.5)

Port MT5 **complet** de l'indicateur ICT Top-Down Confluence (TradingView v2.5 / NinjaTrader).
**Compilé 0 erreur / 0 warning** — installé dans `MQL5\Indicators\`.

## Modules (parité TV/NT)

- **Biais HTF + 2 confirmations PERSISTANTS** — EMA10/20 stacking par TF (D1/H1/M15 réglables) ; l'état ne s'inverse qu'à l'apparition du stack OPPOSÉ (= après croisement EMA10/20). Implémentation : scan arrière du TF jusqu'au dernier stack complet (sans état stocké, robuste aux recalculs).
- **Dashboard** coin haut-droit : Biais / Conf1 / Conf2 / Structure / SIGNAL + **compte à rebours de bougie** (rafraîchi 1 s via OnTimer — fonctionne sur TOUS les TF, D1 inclus : les barres MT5 ont de vraies heures).
- **Structure 2 échelles** : BOS/CHoCH (interne, 5) + MSS/BOS (swing, 20), lignes au swing cassé + tag (CHoCH au-dessus, MSS/BOS dessous).
- **Zone OTE par cassure** : 0.666→0.79, sweet 0.705 (tirets), repère 0.62 (pointillés), cible extension, **A+** = cadre épais si biais HTF aligné, label long dessous / short dessus.
- **Killzones Open/Close** (London O/C, NY O/C, Asie) en **heure New York avec DST automatique** (conversion broker→GMT→NY calculée), N derniers jours réglables.
- **Asian Box** : cadre du range high/low 18:00–23:59 NY (sans fond, bougies lisibles).
- **Macros ICT** : **segments fins en bas du graphe comme sur NT** (3 lanes empilées Londres / Londres+NY / NY PM, couleurs vives), repositionnés en continu selon l'échelle visible (CHART_PRICE_MIN/MAX + OnTimer), visibles uniquement en LTF (≤ `InpMacroMaxMin`, défaut 15 min).
- **Dashboard réductible/fermable** : boutons **[-]** (réduit au bandeau) et **[x]** (**ferme l'indicateur en un clic** via `ChartIndicatorDelete`, purge complète des objets) dans le coin du bandeau.
- **NDOG** : gap clôture veille → ouverture jour (D1 broker), N derniers jours, bornes + **médiane pointillée**, fond pâle, gap nul = trait épais, **label unique « NDOG ETH - jul, 16 2026 »** à l'extrémité droite centré.
- **Liquidités** : BSL/SSL sur les 2 échelles (majeurs pleins / internes tirets), étiquettes BSL au-dessus à gauche / SSL en-dessous à gauche sans prix ; **EQH/EQL** renforcés (trait 2, étiquette avec prix, couleurs dédiées) ; **purge = trait fin gris stoppé à la bougie du sweep**.

## Adaptations propres à MT5 (documentées)

- **Pas de transparence sur les objets MT5** → les fonds (killzones, macros, NDOG) utilisent des **couleurs pâles en arrière-plan** (back=true). Adapter les couleurs si fond de graphique sombre (inputs dédiés).
- **Macros** = segments ancrés au prix (recalés chaque seconde sur le bas de l'échelle visible) — équivalent visuel des lanes pixel de NT.
- **Signaux ▲▼ historiques** non tracés (le biais historique par barre coûterait trop cher) — le dashboard SIGNAL reflète l'état live.
- Le NDOG utilise le **jour broker D1** (sur les brokers GMT+2/+3 type Exness, la clôture D1 ≈ 17:00 NY — cohérent avec la définition ETH).
- Recalcul complet limité aux **5000 dernières barres** (perf).
- **Dashboard déplaçable** : drag par le bandeau (`CHART_EVENT_MOUSE_MOVE`, position mémorisée en variable globale). En corner droit, la distance au bord se calcule `chartW - mx`.

---

# 3. `TA_RiskManager.mq5` — Risk Manager + trade manager (V2.0)

Portage MT5 du **Risk Manager du Trade Assistant NinjaTrader** (voir `../ninjatrader/README.md`). Complément du Trade Assistant MT5 de Kravchenko : celui-ci gère les **positions**, le TA_RiskManager gère le **compte**.

- **Magic** : `260710` · **Compilé** 0 erreur / 0 warning · installé dans `MQL5\Experts\`
- **À la pose** : cocher **« Autoriser les importations DLL »** (uniquement pour que le bouton **DASH** ouvre le navigateur) et activer **Algo Trading**.

## Panneau (déplaçable par le bandeau)

- **Compte** : login, solde, équité en direct.
- **Grades** `A+ / Std / CT / Man` (boutons) : le clic écrit le **% préréglé** dans le champ Risque % et le passe en lecture seule ; **Man** = saisie libre (mémorisée).
- **Lot** (0 = auto au risque) · **SL pts** (0 = **AUTO ATR**) · **TP pts** (0 = RR × SL).
- **Entrée** + **B.LMT / S.LMT** : ordres en attente, type **limit ou stop choisi automatiquement** selon le côté du marché.
- **TPs 1-5** · **TRAIL ON/OFF** · **BE ON/OFF**.
- **BUY / SELL** · **CLOSE ALL** · **DASH**.
- Lignes d'état : `Jour ±% · Serie nP · DD % · ×facteur · VERROU` · `Pos x lot · R y $ · RR z · ±PnL` · `Session n trd · % · R · Expo %`.

## Moteur

- **Jour de trading** = bascule **18:00 New York** (DST automatique) ; états persistés **par compte** en variables globales du terminal.
- **Paliers d'équité** : DD ≥3 % → risque ×0,5 ; ≥6 % → ×0,25. **Objectif jour** +2 % → demi-risque.
- **Limites FTMO-like** : perte jour **5 %** (alerte 4 %), **DD max 10 %** → **fermeture de toutes les positions** (une fois) + **verrou souple** (re-clic ≤ 6 s pour confirmer). **Pause** après 3 pertes consécutives. **Cap d'exposition** 2 % (refus souple).
- **SL AUTO par ATR** (période/coef réglables), borné au *stops level* + spread du broker — indispensable : un SL en points fixes est absurde d'un symbole à l'autre (200 pts = 2 $ sur BTC → « invalid stops » + lot démesuré).
- **Trailing** (distance ATR ou points fixes, armement réglable) et **Break-even à N×R** (actif si le trailing est OFF).
- **Scaling-in consolidé** : une position ajoutée au groupe → **prix moyen**, **SL unique**, TP ré-ancrés en conservant leur RR. Draguer le SL d'une position **aligne tout le groupe**.
- **Drag des ordres en attente** : déplacer une ligne d'entrée déplace **tout le groupe** (SL/TP suivent, distances conservées).
- **Étiquettes sur les lignes** : entrée `BUY 1.76`, SL `−100 $`, TP `+200 $`, pendings `B.PEND`, niveaux partiels à venir `TP2 0.05 (+92 $)`.

## TP partiels — **UNE seule position** (V2.0, refonte)

> ⚠️ **Erreur de conception corrigée.** La V1.3 ouvrait **N tickets** (un par TP) puisqu'un ticket MT5 ne porte qu'un seul TP. Conséquences : N trades comptés (la limite de pertes consécutives sautait), N SL affichés, statistiques faussées.

Désormais, comme les trade managers professionnels : **1 position** (lot total, **1 SL**, TP = cible finale) + **fermetures partielles déclenchées au prix** pour les TP intermédiaires.

- **RR par niveau réglables** : TP1..TP5 = **2 / 4 / 6 / 8 / 10 R** par défaut (0 = répartition uniforme).
- Le **plan de sorties** est persisté par ticket en variables globales → survit à un redémarrage.
- **Journal, série de pertes et stats ne comptent qu'à la clôture COMPLÈTE** de la position, avec le **résultat total** (agrégation de tous les deals, prix d'entrée/sortie moyens pondérés). Le **R réalisé** compare le gain total au **risque initial de l'entrée**.

## Journal & dashboard

- **Tous les trades fermés du compte** sont journalisés (y compris ceux passés par le Trade Assistant Kravchenko ou à la main, toutes paires) dans **`MQL5\Files\TA_Journal.csv`** — **format identique à NinjaTrader** (16 colonnes, Compte = login MT5).
- `TA_View.html` est régénéré avec les données incluses ; le bouton **DASH** l'ouvre. Le template **`TradeAssistant_Dashboard.html`** doit être copié dans `MQL5\Files\` (source dans `../ninjatrader/`).

## Pièges MQL5 rencontrés

- `PFX name` (un `#define` littéral accolé à une **variable**) ne compile pas → `PFX + name` : l'adjacence ne marche qu'entre littéraux.
- `StringFormat` : un `%s` manquant décale **silencieusement** toutes les colonnes suivantes (la colonne Compte disparaissait du journal).
- Les **OBJ_EDIT** ne gèrent pas Ctrl+A (utiliser Fin + retours arrière en automatisation).

---

# 4. ICT Silver Bullet — Stratégie (EA) + Signaux (indicateur)

La version 2.00 implémente un modèle de continuation strict décrit dans
`LOGIQUE_ENTREES.md`. L'EA et l'indicateur s'appuient sur le même moteur de
décision ; ils ne conservent plus deux interprétations séparées de la séquence
d'entrée.

## 4.1 Architecture v2

| Fichier | Responsabilité |
|---|---|
| `ICT_SilverBullet_Core.mqh` | Moteur déterministe sans dépendance MT5 : stacking, chronologie, FVG, Fibonacci, OTE, fenêtres, invalidations et décisions |
| `ICT_SilverBullet_Strategy.mq5` | Adaptateur EA : données MT5, risque, ordres, contrôle du fill, sorties et état persistant |
| `ICT_SilverBullet_Signals.mq5` | Adaptateur indicateur : reconstruction historique, tracés, dashboard, alertes et notifications ; aucun ordre |

Le cœur est compilable directement par les tests C++. Il ne contient ni appel de
trading ni dessin. Avec des événements de bougies, des paramètres **et un état
initial** identiques, l'EA et l'indicateur appliquent les mêmes transitions du
cœur jusqu'à la production d'une `SblDecision`. Leur cycle de vie peut ensuite
diverger :
l'indicateur retire le setup dès une décision de signal, tandis que l'EA peut
revenir en attente si l'ordre ne peut pas être exécuté. L'indicateur ne
connaît ni le verrou du compte, ni les positions, ni les fills et rejets du
broker ; il reconstruit aussi un historique borné alors que l'EA ne reconstruit
pas un setup perdu lors d'un redémarrage.

## 4.2 Logique d'entrée v2

Le contrat de biais est fixe : EMA10/EMA20 sur **D1 + H1 + M5 + M1**. Chaque
timeframe doit être strictement aligné dans le même sens :

```text
LONG  : Close > EMA10 > EMA20 sur D1, H1, M5 et M1
SHORT : Close < EMA10 < EMA20 sur D1, H1, M5 et M1
```

Un stack neutre sur un seul timeframe interdit le setup et invalide ceux de même
direction déjà en attente. Les inputs historiques permettant de désactiver
l'alignement, le filtre D1 ou le MSS restent présents pour charger les anciens
presets, mais doivent rester activés ; toute autre valeur provoque un refus
d'initialisation. L'OTE est pareillement fixé à 62–79 %.

Séquence LONG, obligatoirement chronologique :

1. verrouiller les derniers swings high et low confirmés ;
2. purger le swing low par une mèche puis une clôture de réintégration stricte
   (`Low < swing low AND Close > swing low`) et verrouiller l'extrême comme
   Fibonacci 0 ;
3. former et confirmer un swing high **interne** strict après la purge ;
4. balayer par une mèche le swing high **externe**, qui est alors consommé ;
5. confirmer un vrai croisement MSS par clôture au-dessus du swing high interne,
   le déplacement minimal et une FVG haussière dont la Consequent Encroachment
   est dans le discount ;
6. figer Fibonacci 1 à l'extrême de la jambe, puis attendre une bougie ultérieure
   qui retrace en discount et touche un déclencheur autorisé ;
7. après cette clôture, envoyer un achat au marché si le prix exécutable se
   trouve encore dans le discount.

Le SHORT est le miroir exact : mèche au-dessus du swing high avec clôture de
réintégration, swing low interne post-purge, sweep du swing low externe, MSS sous
le niveau interne, CE de FVG en premium, retracement puis vente.

La FVG de contexte est **toujours obligatoire**. `InpUseFVG=false` désactive
uniquement la FVG comme déclencheur final ; il ne supprime pas cette condition de
structure. Les déclencheurs disponibles sont FVG, OTE 62–79 % et retest EMA10.
Le trigger OTE demande seulement que le range de la bougie intersecte la zone
inclusive 62–79 % ; la bougie n'a pas à traverser toute cette zone.
La CE vaut `(FvgLow + FvgHigh) / 2`. Une FVG traversant l'EQ reste valide si sa CE
se trouve dans la moitié autorisée ; si elle déclenche l'entrée, cette CE doit
être réellement touchée. La bougie doit présenter un rejet directionnel et
clôturer dans la bonne moitié. L'exécution limite n'est pas implémentée.

Les références de liquidité sont identifiées par timestamp. Une origine purgée
ou une cible balayée ne peut pas être recyclée indéfiniment. Le pivot interne
utilisé par le MSS est confirmé par deux bougies de chaque côté et sa source doit
être postérieure à la purge. Le sweep externe et le MSS peuvent être constatés
sur une même bougie si ce pivot était déjà confirmé ; la bougie de purge ne peut
jamais fournir ces événements.

Le détecteur 2/2 produit séparément les événements pivot high et pivot low. Un
pivot confirmé sur la bougie courante peut alimenter la structure interne d'un
setup antérieur, mais il n'est promu comme nouvelle référence externe qu'après le
traitement de cette bougie. Les événements de liquidité courants restent donc
évalués contre les références connaissables avant sa clôture.

## 4.3 Filtre horaire et heure New York

Les plages New York suivantes sont obligatoires et semi-ouvertes :

| Session | Plage d'entrée NY |
|---|---:|
| London Killzone | `[02:00, 05:00)` |
| New York Killzone | `[07:00, 10:00)` |
| Asian Killzone | `[19:00, 22:00)` |

Le timestamp testé est celui de la **clôture** de la bougie. La purge ne peut
créer le setup que dans une de ces plages et toute la séquence doit rester dans
la même instance `date NY + fenêtre`. Une clôture à 05:00, 10:00 ou 22:00, un
passage à une autre fenêtre ou un trou de cotations entre deux fenêtres invalide
le setup. `InpUseSbWindows` reste présent pour charger les anciens presets, mais
doit valoir `true`, faute de quoi l'initialisation est refusée.

La conversion suit `heure broker → UTC → New York`. `InpAutoDST=true` applique
automatiquement EST/EDT à la date de la bougie et est obligatoire dans cette
révision ; `false` est refusé à l'initialisation. Le fuseau serveur doit être
choisi explicitement :

| Mode broker | Usage |
|---|---|
| `AUTO_LIVE` | Déduit l'offset actuel avec `TimeTradeServer-TimeGMT` ; réservé au live, interdit dans le Strategy Tester et déconseillé pour reconstruire l'historique |
| `FIXED` | Utilise `InpBrokerGmtHours` comme offset constant |
| `EUROPE_DST` / `EU_DST` | Utilise `InpBrokerGmtHours` comme offset standard et ajoute l'heure d'été européenne ; mode par défaut, adapté notamment à un serveur GMT+2/GMT+3 |

Un mauvais mode broker décale les fenêtres même si le DST New York est correct.

## 4.4 EA `ICT_SilverBullet_Strategy.mq5` (v2.00, magic 260711)

- **Compte HEDGING obligatoire** : l'initialisation est refusée en netting.
- Entrée au marché au premier tick suivant la confirmation clôturée, uniquement
  si ce tick appartient encore à la même instance de fenêtre New York. Le volume
  est calculé avec `OrderCalcProfit`, puis prix, volume et risque réels sont
  réconciliés depuis le deal ou la position. Un fill hors discount/premium, un
  sur-risque ou une protection non applicable déclenche une fermeture de sécurité.
- SL structurel au-delà de Fibonacci 0. Baseline recommandée et valeurs par
  défaut : TP1 à 2R, partiel 50 %, objectif final 4R et trailing 2R. Après TP1,
  le reliquat passe à break-even ; avec
  `InpTrailRunner=true`, le TP final est retiré et remplacé par le trailing.
- TP1, break-even et trailing sont contrôlés à chaque tick. Si le volume ne permet
  pas deux fractions conformes au pas/minimum broker, aucun partiel n'est envoyé,
  mais le passage à break-even reste prévu à TP1.
- Après une reconnexion, les bougies manquées sont rejouées dans l'ordre pour
  remettre la machine d'état à niveau, mais une opportunité historique n'est
  jamais exécutée au prix courant. Seule la dernière clôture encore récente peut
  envoyer un ordre, et une purge appartenant à un ancien jour New York ne peut
  pas créer aujourd'hui un nouveau setup.
- Risque dynamique par défaut : 1 %, puis 0,5 % après une perte, puis 0,25 % après
  une seconde perte jusqu'au prochain gain. `InpMaxPositions=3` plafonne les
  positions et setups actifs.
- Si une décision ne peut pas être exécutée à cause de la capacité, du risque ou
  d'un prix marché sorti de la zone, le setup déjà formé revient en attente d'un
  nouveau retracement dans la même fenêtre ; cette impossibilité ne l'invalide
  pas à elle seule.
- Après une requête d'ouverture au résultat incertain, l'EA conserve l'éventuel
  ticket d'ordre et l'identifiant de requête, bloque une place de capacité et
  recherche l'exécution réelle. Un reliquat d'ordre d'entrée est annulé et cette
  annulation est réconciliée avant toute fermeture de sécurité. Une position
  apparue tardivement est fermée et la décision n'est pas renvoyée. Les clôtures
  TP1/de sécurité et les modifications SL/TP incertaines sont elles aussi
  sérialisées jusqu'à confirmation du volume, des protections ou de l'état
  historique. `InpBrokerReconcileSeconds=120` borne l'attente lorsqu'il n'existe
  aucun ordre actif ni preuve d'exécution.
- Le verrou journalier utilise le PnL **réalisé** des positions suivies, frais et
  swaps inclus, puis se réinitialise à minuit New York. Il bloque les nouvelles
  entrées ; ce n'est ni un contrôle du drawdown latent ni une fermeture forcée des
  positions déjà ouvertes.

Hors Strategy Tester, le registre des liquidités consommées, le jour NY, le PnL
réalisé, le niveau de risque et le verrou journalier sont sauvegardés par
serveur/compte/magic/symbole dans `Common\Files`. L'écriture passe par un fichier
temporaire puis un remplacement. Le registre conserve au maximum 512 timestamps
par direction. Dans le testeur, chaque exécution repart volontairement d'un état
neuf.

### Sécurité au redémarrage

Les setups en attente et l'état détaillé de gestion d'une position ne sont pas
reconstruits après rechargement ou redémarrage :

- un setup en attente est abandonné ; sa liquidité déjà consommée reste mémorisée ;
- le SL et le TP présents chez le broker restent actifs ;
- si une position ou un ordre actif portant le même magic et le même symbole
  existe au démarrage, l'EA bloque toute nouvelle entrée jusqu'à sa résolution ;
- TP1, break-even et trailing de cette position préexistante ne sont pas repris
  automatiquement.

Il faut donc éviter de redémarrer l'EA avec une position ou une requête Silver
Bullet active, particulièrement si le TP a déjà été retiré au profit du trailing.

## 4.5 Indicateur `ICT_SilverBullet_Signals.mq5` (v2.00)

L'indicateur ne passe aucun ordre. Il rejoue le moteur partagé pour afficher une
aide discrétionnaire :

- EMA10/20 via deux buffers `DRAW_LINE` ;
- triangles LONG/SHORT et, en option, lignes SL/TP1/TP calculées sur le prix de
  clôture du signal ;
- traits des trois fenêtres London 02:00–05:00, New York 07:00–10:00 et Asia
  19:00–22:00 ;
- dashboard déplaçable et réductible : biais, tendance D1, fenêtre, dernier signal
  et compte à rebours de la bougie ;
- alertes et notifications push uniquement pour un nouveau signal live.

`InpShowMacros` est conservé uniquement pour charger les anciens presets et n'a
plus d'effet. Les anciennes lanes de macros ne sont ni des fenêtres d'entrée ni
des éléments affichés par la v2.

La sortie historique est bornée par `InpMaxBarsBack` (3000 par défaut), avec un
préchauffage des swings de `InpSwingWarmupBars` (500). Le registre de liquidité de
l'indicateur est reconstruit sur cet historique borné et n'est pas sauvegardé dans
le fichier d'état de l'EA. Le dashboard retrouve sa position par défaut après un
rechargement. Les objets MT5 n'offrant pas la même transparence que NinjaTrader,
les sessions utilisent couleurs et épaisseurs sans alpha équivalent.

## 4.6 Anciens presets et backtests

> **⚠️ Les résultats IS/OOS publiés avant la v2 mesuraient une autre logique
> d'entrée. Ils ne valident ni les performances, ni les marchés, ni les timeframes
> de la version actuelle et ne doivent pas servir de justification de déploiement.**

Les fichiers historiques suivants sont conservés comme points de départ de
configuration seulement :

- `sets/sets(ICT SB Signaux)/ICT_SB_DE30_M5.set` ;
- `sets/sets(ICT SB Signaux)/ICT_SB_XAUUSD_M5.set` ;
- `sets/sets(ICT SB Signaux)/ICT_SB_FDXS.set`.

Les presets DE30 et XAUUSD fixent encore les sorties historiques 2,5R / 30 % /
6R / trailing 2,5R ; elles ne sont pas les défauts v2 et n'ont pas été revalidées
avec le nouveau moteur. Le preset FDXS ne fixe pas ces valeurs et hérite donc des
défauts v2. Dans les trois presets, `InpUseFVG=false` signifie seulement « pas de
trigger FVG » ; la FVG de contexte reste obligatoire.

Une nouvelle validation doit au minimum recompiler la v2, fixer le mode et
l'offset broker, charger les paramètres via `[TesterInputs]`, puis rejouer les
périodes IS et OOS. L'ancienne méthode headless fondée sur
`ExpertParameters=.set` n'est pas considérée fiable dans ce projet. `OnTester()`
écrit les statistiques v2 dans un CSV `SBopt_v2_*.csv` sous `Common\Files`.

## 4.7 Tests et vérification

Depuis la racine du projet :

```sh
make test
```

Cette commande compile le moteur partagé en C++17 strict, exécute les scénarios
LONG/SHORT et les cas de rejet, puis lance les contrats structurels vérifiant que
l'EA et l'indicateur utilisent bien ce moteur.

```sh
make verify
```

`make verify` ajoute la compilation réelle des deux `.mq5` par MetaEditor dans un
répertoire temporaire. Sur l'installation macOS prévue par le script, MetaEditor
est lancé sous Wine. Les chemins peuvent être adaptés avec `MT5_WINE_BIN`,
`MT5_WINEPREFIX` et `MT5_METAEDITOR`.

Commandes ciblées :

```sh
make test-core       # tests déterministes du moteur
make test-contracts  # contrats statiques EA/indicateur/cœur
make test-mql5       # compilation MetaEditor uniquement
```

La suite couvre notamment le stacking strict, la purge réintégrée, les pivots
internes post-purge, la séparation sweep externe/MSS, la CE de FVG, OTE, EMA,
les liquidités consommées, les 540 minutes de fenêtres, leur identité et les
transitions DST US/Europe. Les tests de contrat restent statiques et la
compilation MetaEditor ne remplace pas un backtest v2, un test de redémarrage ni
des essais de fills, rejets et fermetures partielles avec un broker réel.
