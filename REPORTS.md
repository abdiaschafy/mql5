# REPORTS — Backtests MT5 (données broker réelles)

EA `ICT_Structure_OTE_EA` — Strategy Tester MT5, broker **Exness-MT5Trial10**, symbole **US500**, dépôt **30 000 $**, période **02/01/2025 → 10/07/2026** (18 mois, marché mixte), modèle 1-min OHLC, spread réel, A+ actif.

## Résultats — zone OTE 0.666 → 0.79 (v1.10, alignée indicateur v2.2) ⭐ ACTUEL

| TF | Trades | Win rate | **Profit Factor** | Profit | **DD max** | Espérance/trade |
|---|---|---|---|---|---|---|
| **H1** ⭐ | 85 | 48,24 % | **1,463** | +9,84 % (+2 952 $) | **3,50 %** (1 191 $) | +34,73 $ |
| M15 | 229 | 39,30 % | 0,999 | −0,12 % | 14,01 % | −0,16 $ |

**A/B vs zone 0.62** : en **H1 la zone 0.666 améliore tout** (PF 1,387→1,463, DD 4,20→3,50 %, espérance +29→+35 $) — entrées plus profondes = meilleur prix. En **M15 elle tue l'edge marginal** (PF 1,106→0,999) : confirmation que M15 = bruit + spread, **H1 = TF de travail**.

## Résultats — zone historique 0.62 → 0.79 (v1.00, référence)

| TF | Trades | Win rate | **Profit Factor** | Profit | **DD max** | Espérance/trade |
|---|---|---|---|---|---|---|
| **M15** | 239 | 39,33 % | 1,106 | +8,95 % (+2 684 $) | 14,62 % (5 199 $) | +11,23 $ |
| **H1** | 90 | 48,89 % | **1,387** | +8,71 % (+2 613 $) | **4,20 %** (1 429 $) | +29,03 $ |

## Lecture

1. ✅ **Port fidèle** — MT5 H1 (**PF 1,387**) reproduit la référence TradingView H1 (PF 1,37). La stratégie a été portée correctement.
2. ✅ **Edge réel** — sur données broker réelles (spread inclus), H1 donne **PF 1,39 / +8,71 % / DD seulement 4,20 %** sur 18 mois mixtes.
3. ⚠️ **M15 = marginal** — 239 trades, PF 1,11 : trop de trades → le **spread réel grignote** les nombreux petits trades M15. Pattern récurrent du projet : **H1 propre > M15 bruité**.

➡️ **H1 = le sweet spot.** C'est le meilleur résultat validé du projet pour l'approche structure-OTE.

## Méthode (headless, reproductible)

- Fermer MT5 (1 instance / dossier de données).
- `terminal64.exe /config:sets\backtest_US500_H1.ini` → run + shutdown auto (~1-2 s, historique local).
- Stats écrites par `OnTester()` dans `...\Terminal\Common\Files\ict_bt_stats.txt` (le rapport HTML `/config` ne s'écrit pas de façon fiable).
- Relancer MT5 ensuite.
- ⚠️ **Piège** : le testeur recharge les **derniers inputs** (`MQL5\Profiles\Tester\<EA>.set`), PAS les défauts du code — un changement de défaut recompilé ne prend pas effet. Forcer via une section `[TesterInputs]` dans l'ini (ex. `InpOteShallow=0.666`).

## Multi-marchés — US30 & USTEC (14/07/2026, A/B zones 0.62 vs 0.666)

| Symbole | TF | Zone 0.62 | Zone 0.666 |
|---|---|---|---|
| US30 | H1 | **PF 1,276 · +6,4 % · DD 4,8 %** | PF 1,116 · +2,7 % |
| US30 | M15 | PF 1,141 · +13,1 % · DD 15,9 % | **PF 1,237 · +21,0 % · DD 14,7 %** |
| USTEC | H1 | PF 1,072 · +1,3 % | PF 1,062 · +1,1 % |
| USTEC | M15 | PF 1,008 · +0,6 % | PF 1,074 · +5,3 % |

**Lecture :**
- **USTEC = pas d'edge** (PF 1,0-1,07 partout) → **exclu**.
- **US30 = edge présent** (3/4 cellules PF > 1,11) mais inversé vs US500 : le **M15** performe (PF 1,24, +21 %, DD ~15 %), le H1 est moyen.
- ⚠️ **L'effet 0.666 n'est PAS consistant cross-marché** (aide US500-H1 et US30-M15, dégrade US30-H1 et US500-M15) → les écarts de zone = largement du bruit ; le choix de zone est **second ordre** vs le couple symbole×TF. Le 0.666 est conservé pour la **cohérence méthodologique** (indicateur v2.2), pas comme optimisation.
- **Robuste** : US500 H1 garde l'edge dans les deux zones (PF 1,39-1,46) = socle du portefeuille.

**Portefeuille candidat** : US500 H1 (cœur) + US30 M15 (diversifieur à valider en forward, DD plus rugueux). USTEC exclu.

## XAUUSD (14/07/2026, A/B zones, 18 mois, dépôt 30K)

| TF | Zone 0.62 | Zone 0.666 |
|---|---|---|
| H1 | PF 0,902 · −1,75 % | PF 0,784 · −3,44 % |
| **M15** | **PF 1,555 · +41,3 % · DD 13,3 %** | **PF 1,523 · +36,5 % · DD 13,4 %** |

- **XAUUSD M15 = le meilleur résultat M15 du système** (PF ~1,5, espérance ~55 $/trade, ~210 trades) — cohérent avec l'historique du projet (l'or aime les stratégies ICT M15, cf. ICT_Swing_LiqFVG XAU PF 2,76).
- **XAUUSD H1 = négatif** — même profil que US30 : l'edge or est en M15, pas en H1 (inverse de US500).
- Les deux zones marchent en M15 (0,62 légèrement mieux) — confirme que la zone est un choix de second ordre.
- ⚠️ `InpSLBuffer=5.0` est en unités de prix : 5 $ sur l'or ≈ 0,12 % du prix (comparable aux 5 pts US500) — OK par chance, mais à paramétrer en % si multi-actifs hétérogènes.

**Portefeuille candidat révisé** : US500 H1 (PF 1,46) + XAUUSD M15 (PF 1,52) + US30 M15 (PF 1,24). USTEC exclu.

## Forward test démo — EN COURS depuis le 14/07/2026

- **US500 H1 + US30 M15 + XAUUSD M15**, compte démo Exness-MT5Trial10, EA v1.10, zone 0.666, magic 260709.
- Installés via graphiques du profil (`MQL5\Profiles\Charts\Default\*.chr` avec bloc `<expert>`) → **persistent aux redémarrages** (validé).
- Cibles backtest à comparer : US500 H1 PF 1,46 · US30 M15 PF 1,24 · XAUUSD M15 PF 1,52.
- Suivi : journal Experts MT5 (`MQL5\Logs\`), positions magic 260709.

### ⚠️ Précautions backtests headless (2 incidents documentés)
1. Les lancements headless (`/config` + `[Tester]` + `ShutdownTerminal=1`) **purgent les EA attachés aux graphiques** (le profil est réécrit sans les blocs `<expert>`). → Sauvegarder les `.chr` et les restaurer après.
2. **NE JAMAIS `Stop-Process -Force` sur terminal64** : MT5 écrit le profil au shutdown (peut prendre >5 s avec de gros graphiques) ; un kill pendant l'écriture **tronque le profil** (perte de graphiques — incident du 14/07 : 13 graphiques perdus). → Procédure sûre : **sauvegarder le profil PENDANT que MT5 tourne** (les `.chr` sur disque sont stables), puis `CloseMainWindow` et **attendre la fin réelle du process** (boucle `HasExited`, jusqu'à 60 s) avant tout lancement.

## À faire ensuite

- Suivre le forward (comparer aux stats backtest : US500 H1 PF 1,46 / US30 M15 PF 1,24).
- Vérifier `InpNYGMTOffset` (DST) — le H1 propre suggère ~correct.
- Réattacher le forward **EMA1020_sclap** (US30 + US500) si souhaité — il a été débranché par les cycles headless.
