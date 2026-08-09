# ICT — MQL5 (MetaTrader 5)

| Fichier | Type | Rôle |
|---|---|---|
| `ICT_Structure_OTE_EA.mq5` | **EA** (magic 260709) | Stratégie structure→OTE backtestable/live |
| `ICT_TopDown_Confluence.mq5` | **Indicateur** | Port MT5 **complet** de l'indicateur v2.5 (TV/NT) — section 2 |
| `TA_RiskManager.mq5` | **EA panneau** (magic 260710) | **Risk Manager + trade manager** : portage MT5 du Trade Assistant NT — section 3 |
| `ICT_SilverBullet_Strategy.mq5` | **EA** (magic 260711) | Stratégie **Silver Bullet** (modèle continuation) — section 4 |
| `ICT_SilverBullet_Signals.mq5` | **Indicateur** | **Signaux Silver Bullet** (EMA10/20, triangles, killzones en bas, dashboard déplaçable) — section 4 |

> ⚠️ **Recharger un EA/indicateur MT5** : recompiler **ne suffit pas** (l'image reste en cache pour la session), et le re-glisser sur le graphique non plus → **redémarrer le terminal**. L'EA se ré-attache seul avec le graphique, réglages DLL conservés.

---

# 1. ICT Structure OTE EA

`ICT_Structure_OTE_EA.mq5` — portage MT5 de la stratégie Pine `ICT_Structure_OTE_Strategy` (dossier `../pine/`). EA natif, **symbol-agnostic** (indices US : US500 / US30 / USTEC / DE30).

- **Magic** : `260709`
- **Compilé** : 0 erreur / 0 warning
- **Installé** : `...\MetaQuotes\Terminal\<hash>\MQL5\Experts\`
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

## Backtest headless (reproductible)

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

Portage MT5 (25/07/2026) de la stratégie et de l'indicateur NinjaTrader `ICTSilverBulletStrategy` / `ICTSilverBulletSignals` (dossier `../ninjatrader/`). **Modèle CONTINUATION** (corrigé) : biais stacking EMA10/20 H1+M5+M1 aligné + filtre tendance Daily → **sweep = PURGE de la liquidité OPPOSÉE** (LONG = purge d'un ancien swing HIGH ; SHORT = purge d'un swing LOW) → retracement dans le **discount/premium** → entrée **FVG / OTE / retest EMA** + MSS, dans les **killzones NY** (DST auto). SL structurel, TP1 2R (partiel) + BE, runner 4R/trailing. Risque dynamique **1 / 0,5 / 0,25 %**, max 3 positions, verrou DD 5 %/jour.

## 4.1 EA `ICT_SilverBullet_Strategy.mq5` (magic 260711)

- **Compilé** 0 erreur / 0 warning · installé dans `MQL5\Experts\`.
- **⚠️ Compte HEDGING requis** (netting → les 3 setups fusionnent).
- **Core/runner émulés en UNE position** : ouverture volume total (SL structurel + TP = 4R) ; à 2R → `PositionClosePartial` du core (`Tp1Percent`) + SL → BE ; si trailing → TP retiré puis stop suit l'extrême à `TrailR×R`.
- **Sizing en lots** (`SYMBOL_TRADE_TICK_VALUE/SIZE`), risque dynamique via `FinalizeSetup` (PnL historique par position à la clôture totale → `riskLevel` 0/1/2).
- **Heure NY DST auto** (`IsUSDST` : 2ᵉ dim. mars → 1ᵉʳ dim. nov). Logique 1×/barre.
- **Configs validées OOS** : `../sets(ICT SB Signaux)/ICT_SB_DE30_M5.set` et `ICT_SB_XAUUSD_M5.set` (entrée EMA+MSS+Trend+killzones, FVG off, TP1R 2,5 / FinalR 6 / TrailR 2,5 / TP1% 30, SL 4 DAX / 8 or). `ICT_SB_FDXS.set` = ancien baseline négatif en OOS, obsolète.

### Backtests + validation OOS (Exness CFD, M5, 50k fixe, `[TesterInputs]`)

> **⚠️ Correction 25/07** : les 1ers chiffres (« DE30 +44 359/PF 1,13, or −3 967 disqualifié ») étaient FAUX — `ExpertParameters=.set` en `/config` **ne charge pas** le .set → l'EA tournait sur ses défauts (FVG on, killzones OFF, equity composé). Bonne méthode = section **`[TesterInputs]`** du .ini.

Balayage 486 configs/marché, découpage IS (2024→mi-25) / OOS (mi-25→mi-26) :

| Marché | Baseline IS | Baseline OOS | r IS↔OOS | Verdict |
|---|---|---|---|---|
| **DE30** (tuné) | +44 489 · PF 2,62 | **+5 251 · PF 1,30** | 0,81 | ✅ **déployable** |
| **XAUUSD** | +6 464 · PF 1,21 | **+2 417 · PF 1,09** | −0,79 | ✅ **déployable** (modeste) |
| US500 | −2 347 · PF 0,94 | +6 518 · PF 1,29 | 0,92 | ❌ OOS-seulement |
| US30 | −6 919 · PF 0,81 | +3 232 · PF 1,14 | 0,11 | ❌ IS négatif + bruit |
| USTEC / BTCUSD / EURUSD / GBPUSD | — | — | — | ❌ (BTC 0/486 positif ; forex 64 configs testées) |

- **Critère : profitable dans les DEUX périodes** (edge stable) vs OOS-seulement (chance de régime). Seuls **DE30 + XAUUSD** passent (positifs IS **et** OOS). US500/US30 étaient négatifs/plats en in-sample → leur profit récent = régime, pas edge.
- **Le réglage clé (DE30)** : TP1R 2,0→2,5 + TP1% 50→30 (« laisser courir ») fait passer l'OOS de négatif (baseline) à positif.
- **Magnitude modeste** : le PF in-sample déflate ~2× en OOS (DAX 2,6→1,3). Attentes réelles : DE30 ~PF 1,3, or ~PF 1,1.
- **⚠️ M5 obligatoire** : en M1 les SL serrés gonflent les lots → le spread du CFD dévore le R (DE30 M1 = −48 %).
- **Caveats** : Model 1-min OHLC = spread fixe (live variable un peu moins bon) ; RR CFD limitant → un broker à spreads serrés améliorerait l'auto.

## 4.2 Indicateur `ICT_SilverBullet_Signals.mq5` (v1.10)

Outil de signaux **sans ordre** (aide discrétionnaire), même modèle continuation que l'EA. **Compilé 0/0** · installé dans `MQL5\Indicators\`.

- **EMA10/20 tracées** (2 buffers DRAW_LINE bleu/rouge, `InpShowEma`) — base de la logique, rendue visible.
- **Triangles** vert (LONG, code 233) / rouge (SHORT, code 234) au signal ; **lignes SL/TP1/TP** optionnelles (`InpShowSlTp`).
- **Killzones = traits en bas** (OBJ_TREND horizontaux près de `CHART_PRICE_MIN`, London/AM/PM SteelBlue/SeaGreen/Goldenrod) + **macros** pointillées (3:45 / 10:45 / 14:45 NY), reconstruits sur `CHART_CHANGE` + nouvelle barre.
- **Dashboard style NT déplaçable** : table 2 colonnes (82/178), header bleu + boutons **– (réduit) / ✕ (ferme)**, cellules valeur colorées (Biais / Tendance / Fenêtre / Signal) + **décompte de bougie** (OnTimer 1 s) ; drag par l'en-tête (`CHART_EVENT_MOUSE_MOVE`) ; défaut haut-centre.
- **Heure NY EST** : offset **broker→GMT** auto-détecté (`TimeTradeServer` − `TimeGMT`, override `InpBrokerGmtHours`), puis `+ nyOff` (DST auto). Traite l'historique borné `InpMaxBarsBack` (défaut 3000).

### Adaptations / limites MT5 (documentées)

- Pas d'alpha par objet MT5 → l'« opacité 3 » de NT devient couleur + épaisseur.
- Le dashboard est déplaçable en session mais **sa position n'est pas persistée** après recompile/reload (NT la sauvait) → repart au centre-haut.
- Si les traits de killzone tombent à côté de l'heure NY → fixer `InpBrokerGmtHours` (offset GMT du serveur) au lieu de l'auto (99).
- **Piège corrigé** : condition de chevauchement fenêtre/vue inversée dans `RebuildLanes` (`tLeft`/`tRight` permutés) → aucune killzone ne s'affichait ; corrigé en `b>=tLeft && a<=tRight` + clamp, objets au premier plan (`BACK=false`).

> Côté NT : les EMA10/20 ont aussi été ajoutées à `ICTSilverBulletSignals.cs` (input « Afficher EMA rapide/lente » + 2 AddPlot bleu/rouge) — elles n'y étaient pas tracées. **F5** dans NinjaTrader pour les activer.

## 4.3 Lancer un backtest headless (reproductible)

Orchestration multi-symboles : `scratchpad/scan_markets.sh` (ferme le terminal → boucle de configs `/config` avec `ShutdownTerminal=1` → parse les rapports `.htm` UTF-16 → relance le terminal). Config type dans `[Tester]` : `Expert=ICT_SilverBullet_Strategy.ex5`, `ExpertParameters=ICT_SB_FDXS.set` (dans `MQL5\Presets\`), `Symbol=DE30`, `Period=M5`, `Model=1`, `FromDate/ToDate`, `Deposit=50000`, `ShutdownTerminal=1`.
