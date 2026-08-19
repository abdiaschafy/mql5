# SET MGC - Micro Or (Gold)

- **Instrument** : MGC (contrat courant) · **Graphe : 1 minute**
- **Usage** : ✋ **DISCRÉTIONNAIRE** - indicateur `ICT Silver Bullet Signals` (triangles + alertes ; tu exécutes à la main)
- **⚠️ PAS en auto** : le backtest donne un DD de **−63 %** (~20 mois sous l'eau jusqu'à −54 %) avant récupération. C'est un **pari « long or en tendance »**, pas un edge stable.

## Quand le trader
- **Seulement quand l'or est en tendance HAUSSIÈRE claire** (biais D1 haussier, EMA10>EMA20 stacking sur le Daily).
- **Privilégier les LONGS** : au backtest les shorts perdent (PF 0,76) - l'edge est du côté long (rallye de l'or).
- Attendre la séquence complète : purge d'un swing high → retracement en discount → triangle vert dans la killzone.

## Réglages (ICT Silver Bullet Signals - indicateur)

### 1. Biais & Alignement
| Réglage | Valeur |
|---|---|
| TF Biais HTF | **H1** |
| TF Confirmation 1 | **M5** |
| TF Confirmation 2 | **M1** |
| EMA rapide / lente | **10 / 20** |
| Exiger l'alignement des TF | ✅ ON |
| Sens des signaux | **Both** (ou **LongOnly** conseillé sur l'or) |
| Filtre tendance | ✅ ON |
| TF du filtre tendance | **D1** |

### 2. Modèles de signal
| Réglage | Valeur |
|---|---|
| Signal OTE (62-79 %) | ❌ **OFF** |
| Signal FVG (post-sweep) | ✅ **ON**  ← spécifique MGC |
| Signal retest EMA | ✅ **ON** |
| Déplacement min (ticks) | 20 |
| Expiration du setup (barres) | 30 |
| Exiger une cassure de structure (MSS) | ✅ ON |
| MSS : fenêtre de validité | 15 |

### 3. Niveaux affichés
| Buffer SL structurel (ticks) | 4 · TP1 (R) 2 · TP final (R) 4 |

### 4. Filtre & visuel
| Restreindre aux fenêtres Silver Bullet | ✅ ON |
| Afficher killzones / macros | ✅ / ✅ |
| Tableau de bord / Décompte / Alertes | ✅ / ✅ / ✅ |
| Opacité triangles (0-10) | 3 |
| Afficher lignes SL/TP | ❌ OFF (au choix) |

## Utilisation
1. Graphe **MGC · 1 min** → glisser l'indicateur **ICT Silver Bullet Signals** → appliquer ces réglages.
2. Superposer l'indicateur riche **ICT Silver Bullet** si tu veux tout le contexte visuel (FVG, fenêtres, macros, cibles).
3. À chaque triangle vert (en tendance haussière or) : valider le contexte, puis exécuter à la main via le **Trade Assistant**, sizer avec le **Risk Manager**.

---

### Réf. auto (NE PAS trader en auto - pour mémoire)
Config stratégie MGC = FVG+EMA+MSS+Trail+FiltreD, Both. Backtest 2,5 ans / 50k : +33 290 $, PF 1,13, **DD −31 267 $ (−63 %)**, Sortino 0,68. Disqualifié en auto à cause du drawdown.
