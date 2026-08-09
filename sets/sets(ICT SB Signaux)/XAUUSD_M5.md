# SET XAUUSD — ICT Silver Bullet Strategy (EA) · exécution M5

- **EA** : `ICT_SilverBullet_Strategy.mq5` (magic 260711) · **Graphe : M5** · compte **HEDGING**
- **Fichier de réglages VALIDÉ OOS** : **`ICT_SB_XAUUSD_M5.set`**
- **Statut** : ✅ **candidat auto n°2** (après DE30) — edge **modeste mais robuste**.

## Pourquoi XAUUSD est déployable (et pas les indices US)

Balayage 486 configs, découpage IS (2024→mi-2025) / OOS (mi-2025→mi-2026), 50k fixe :

| | Baseline IS | Baseline OOS | Toutes configs |
|---|---|---|---|
| **XAUUSD** | +6 464 · PF 1,21 | **+2 417 · PF 1,09** | **486/486 positives** (IS et OOS) |

- **Positif dans les DEUX périodes** = edge stable (pas un artefact de régime récent, contrairement à US500/US30 qui étaient négatifs en in-sample).
- **Corrélation IS↔OOS négative (−0,79)** : ça veut dire que le **choix fin de config n'a aucune importance** — toutes les configs gagnent des deux côtés. L'edge est **dans le marché** (le rallye de l'or), pas dans le réglage. Donc : config-agnostique, ne pas sur-optimiser.
- **Magnitude modeste** : attente réaliste ~**PF 1,10**, DD ~12 %. C'est un « pari long or en tendance » qui a un vrai bord, mais fin.

## Réglages (`ICT_SB_XAUUSD_M5.set`)

| Input | Valeur | Note |
|---|---|---|
| InpUseOTE | **false** | |
| InpUseFVG | **false** | |
| InpUseEmaRetest | **true** | |
| InpRequireMSS | **true** | |
| InpUseTrendFilter | **true** | filtre Daily |
| InpUseSbWindows | **true** | killzones NY |
| InpTp1R | **2,5** | « laisser courir » |
| InpFinalR | **6,0** | |
| InpTrailR | **2,5** | |
| **InpSlBufferTicks** | **8** | ← plus large que DE30 (volatilité de l'or) |
| InpMinDispTicks | **20** | non contraignant |
| InpTp1Percent | **30** | prendre peu au TP1 |
| InpUseAccountEquity | **false** | (live : `true`) |
| InpAccountSize | **50000** | |
| InpTradeDir | **0 = Both** | |

> Comme le choix de config est du bruit sur l'or, ces valeurs = un template raisonnable (le même « laisser courir » que la DAX + SL élargi). N'importe quelle config de la famille donne ~PF 1,1 OOS.

## Lancer le forward-test M5 (Sim démo)
1. Graphe **XAUUSD · M5**, stream live vérifié.
2. Glisser `ICT_SilverBullet_Strategy` → onglet *Entrées* → **Charger** `ICT_SB_XAUUSD_M5.set`.
3. Live : passer **InpUseAccountEquity = true**. Autoriser l'AutoTrading.
4. Suivre le journal + l'onglet *Trade*. Ne pas surdimensionner (edge fin).

## Caveats
- Edge **modeste** (PF ~1,1) : dimensionner petit, ne pas en attendre la DAX.
- Dépend du **régime haussier de l'or** — un range prolongé peut l'annuler.
- Model 1-min OHLC = spread fixe → live variable un peu moins bon.
