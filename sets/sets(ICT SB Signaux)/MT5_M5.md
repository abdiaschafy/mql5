# SET MT5 - ICT Silver Bullet Strategy (EA) · exécution M5

- **EA** : `ICT_SilverBullet_Strategy.mq5` (magic 260711) · **Graphe : M5**
- **Fichier de réglages VALIDÉ OOS** : **`ICT_SB_DE30_M5.set`** (à charger via *Charger* dans l'onglet Entrées). `ICT_SB_FDXS.set` = ancien baseline (négatif en OOS, ne plus utiliser).
- **⚠️ Compte HEDGING requis** (netting → les 3 setups fusionnent).
- **⚠️ M5 obligatoire, PAS M1** : en M1 les SL structurels sont trop serrés → lots gonflés → le spread du CFD dévore le R (test DE30 M1 = **−48 %**). M5 = TF d'exploitation.

## ⚠️ CORRECTION (25/07) - anciens chiffres invalides

Les premiers backtests DE30 (+44 359, PF 1,13, DD 25,6 %, 1533 trades) étaient sur la **MAUVAISE config** : `ExpertParameters=.set` dans un `/config` headless **ne charge pas** le .set → l'EA tournait sur ses **défauts** (FVG on, killzones OFF, sizing composé). La bonne méthode headless = section **`[TesterInputs]`** dans le .ini. Chiffres corrigés ci-dessous.

## Backtests DE30 corrects (Exness CFD, M5, 50 000 $ fixe, Model 1-min OHLC, `[TesterInputs]`)

| Config | Période | Net | PF | DD max | Trades | Verdict |
|---|---|---|---|---|---|---|
| Baseline (2,0/4,0/2,0/4/20/50 %) | 2024-2026 (IS) | +37 384 | 2,34 | 5,0 % | 394 | in-sample |
| Baseline | **OOS mi-25→mi-26** | **−576** | **0,97** | 11,3 % | - | ❌ négatif OOS |
| **VALIDÉE (2,5/6/2,5/4/20/30 %)** | 2024-2026 (IS) | +44 489 | 2,62 | 7,0 % | 366 | in-sample |
| **VALIDÉE** | **OOS mi-25→mi-26** | **+5 251** | **1,30** | 12,2 % | 122 | ✅ **positif OOS** |

**Validation OOS (486 configs optimisées sur IS puis re-testées sur OOS)** : corrélation profit IS↔OOS **r=0,81**, **top 30 IS = 30/30 positives en OOS**. Le réglage « laisser courir » (**TP1R=2,5 + TP1%=30**) fait passer l'OOS de négatif (baseline) à positif. **Edge RÉEL mais MODESTE : attente réaliste ~PF 1,3, ~+10 %/an sur 50k, DD ~12 %** - régime-dépendant (haussier DAX). Ne pas surdimensionner.

## Réglages (`ICT_SB_DE30_M5.set` - VALIDÉ OOS)

| Input | Valeur |
|---|---|
| InpUseOTE | **false** |
| InpUseFVG | **false** ← spécifique DAX/indices |
| InpUseEmaRetest | **true** |
| InpRequireMSS | **true** |
| InpTrailRunner | **true** |
| InpUseTrendFilter | **true** (filtre Daily) |
| InpUseSbWindows | **true** (killzones NY) |
| **InpTp1R** | **2.5** ← optimisé (encaisser le partiel plus loin) |
| **InpFinalR** | **6.0** |
| **InpTrailR** | **2.5** |
| **InpSlBufferTicks** | **4** |
| **InpMinDispTicks** | **20** (non contraignant) |
| **InpTp1Percent** | **30** ← optimisé (prendre moins au TP1, laisser courir) |
| InpUseAccountEquity | **false** |
| InpAccountSize | **50000** (parité backtest ; en live, passer `UseAccountEquity=true`) |
| InpTradeDir | **0 = Both** |
| *(reste)* | défauts : HTF H1 / Conf1 M5 / Conf2 M1 / Trend D1, EMA 10/20, risque 1/0,5/0,25 %, max 3 positions, DD 5 %/jour, DST auto |

> Le passage baseline → validé = **TP1R 2,0→2,5** et **TP1% 50→30** (« laisser courir »). C'est ce qui rend l'edge positif en OOS.

## Lancer un forward-test M5 (Sim démo)
1. Graphe **DE30 · M5**, vérifier le stream live.
2. Glisser `ICT_SilverBullet_Strategy` sur le graphe → onglet *Entrées* → **Charger** `ICT_SB_DE30_M5.set`.
3. Pour le live, mettre **InpUseAccountEquity = true** (sizing sur le vrai solde) ; garder AccountSize en repli.
4. Autoriser l'AutoTrading. Suivre le journal + l'onglet *Trade*.

## Caveats
- Model 1-min OHLC = **spread « courant » fixe** → le live avec spreads variables (news) sera un peu moins bon. Un test *ticks réels* (Model 4) tranchera si l'historique le permet.
- 2024-2026 = **même période que la validation NinjaTrader** ⇒ confirmation de transférabilité, **pas un OOS neuf**. Le vrai OOS = le forward-test.
- Le **RR CFD (~1,1)** est le facteur limitant. Un broker à spreads serrés (ou le future via un autre broker) améliorerait nettement l'auto.
- Scan multi-marchés M5 (XAUUSD/US30/US500/USTEC/BTCUSD) : voir `README.md` une fois consigné.
