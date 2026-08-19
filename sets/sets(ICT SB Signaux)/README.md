# Sets ICT Silver Bullet - configs de trading

**Modèle** : continuation ICT (purge de la liquidité opposée → retracement dans le discount/premium → entrée FVG / OTE / retest EMA + MSS, dans les killzones NY). Biais = stacking EMA10/20 multi-TF aligné + filtre tendance Daily.

## Bilan backtest (01/01/2024 → 30/06/2026, 2,5 ans, compte 50 000 $, money management 1 % / 0,5 % / 0,25 % actif, commissions incluses)

| Instrument | Set | Net | PF | Max DD | Ret/DD | Sortino | Statut |
|---|---|---|---|---|---|---|---|
| **FDXS (Micro DAX)** | EMA+MSS | +35 613 $ | 1,26 | −12 204 $ (−24 %) | 2,9 | 1,46 | ✅ **AUTO** (forward-test Sim) |
| **MGC (Micro Or)** | FVG+EMA+MSS | +33 290 $ | 1,13 | **−31 267 $ (−63 %)** | 1,06 | 0,68 | ⚠️ **DISCRÉTIONNAIRE seulement** |
| MNQ / MYM / MES | - | négatif / marginal | <1,1 | - | - | - | ❌ écartés |

**Pourquoi FDXS en auto et MGC à la main :**
- **FDXS** : DD contenu (−24 %), le money management fonctionne (réduit le risque en drawdown), courbe qui finit près des sommets.
- **MGC** : DD catastrophique **−63 %**, **~20 mois sous l'eau (jusqu'à −54 %)** avant que le rallye de l'or ne le sauve. Shorts perdants → c'est un **pari « long or en tendance »**, un seul régime. Intenable en auto ; utilisable à la main quand l'or trend clairement.

## Fichiers
- **`FDXS.md`** → set STRATÉGIE AUTO (forward-test en Sim démo).
- **`MGC.md`** → set INDICATEUR SIGNAUX (discrétionnaire).

## Portage MT5 (25/07) - EA `ICT_SilverBullet_Strategy.mq5` + indicateur `ICT_SilverBullet_Signals.mq5`

Exécution **M5** (le M1 est non-viable : SL serrés → lots gonflés → le spread du CFD dévore le R). Compte **HEDGING** requis.

### ⚠️ Correction méthodo (25/07)
Les premiers backtests MT5 (« DE30 seul gagnant +44 359 / PF 1,13 ; or −3 967 disqualifié ») étaient **FAUX** : `ExpertParameters=.set` en headless `/config` **ne charge pas** le .set → l'EA tournait sur ses **défauts** (FVG on, killzones OFF, sizing composé). Bonne méthode = section **`[TesterInputs]`** du .ini. Chiffres ci-dessous = corrects.

### Balayage 486 configs/marché + validation OOS (IS 2024→mi-25 · OOS mi-25→mi-26, 50k fixe)

| Marché | Baseline **IS** | Baseline **OOS** | r IS↔OOS | Verdict |
|---|---|---|---|---|
| **DE30** (config tunée) | +44 489 · PF 2,62 | **+5 251 · PF 1,30** | 0,81 | ✅ **DÉPLOYABLE** (fort) |
| **XAUUSD** | +6 464 · PF 1,21 | **+2 417 · PF 1,09** | −0,79 | ✅ **DÉPLOYABLE** (modeste, robuste) |
| US500 | −2 347 · PF 0,94 | +6 518 · PF 1,29 | 0,92 | ❌ profitable OOS **seulement** |
| US30 | −6 919 · PF 0,81 | +3 232 · PF 1,14 | 0,11 | ❌ négatif IS + sélection = bruit |
| USTEC / BTCUSD | - | - | - | ❌ (BTC 0/486 config positive) |
| EURUSD / GBPUSD (forex) | - | - | - | ❌ pas d'edge (64 configs testées) |

**Critère de décision = profitable dans les DEUX périodes (edge stable) vs OOS-seulement (chance de régime).**
- **DE30** ✅ : positif IS **et** OOS, classement qui se transfère. Config `ICT_SB_DE30_M5.set`.
- **XAUUSD** ✅ : positif IS **et** OOS, **toutes** les configs gagnantes des 2 côtés. Edge modeste mais consistant. Corrélation négative = le **choix de config est du bruit** (l'edge est dans le rallye de l'or) → config-agnostique, `ICT_SB_XAUUSD_M5.set` (SL 8 pour la volatilité).
- **US500 / US30** ❌ : **plats/négatifs en in-sample**, positifs seulement en OOS récent = piège de rétrovision (en 2024 tu aurais perdu / jamais déployé). Pas un edge stable.

**Le réglage qui fait la différence** (DE30) : passer de TP1R 2,0→**2,5** et TP1% 50→**30** (« laisser courir ») rend l'OOS positif ; le baseline seul est négatif en OOS.

## Fichiers
- **`ICT_SB_DE30_M5.set`** → config auto DE30 validée OOS (à charger via *Charger* dans l'EA). **`MT5_M5.md`** = fiche détaillée.
- **`ICT_SB_XAUUSD_M5.set`** → config auto XAUUSD validée OOS.
- `ICT_SB_FDXS.set` → ancien baseline (négatif OOS, **ne plus utiliser**).
- `FDXS.md` / `MGC.md` → fiches historiques (chiffres NinjaTrader d'origine).

## Rappels
- Exécution **M5**, compte **HEDGING**. Signaux dans les **killzones** NY (03-04 / 10-11 / 14-15 ≈ 09-10h / 16-17h / 20-21h Paris).
- Chiffres **in-sample déflatent ~2× en PF** vers l'OOS (DAX 2,6→1,3) → attentes réelles modestes : DE30 ~PF 1,3, or ~PF 1,1.
- **Reste à faire : forward-test Sim de DE30 + XAUUSD** (le live tranche).
- Verdict daté du **25/07/2026**.
