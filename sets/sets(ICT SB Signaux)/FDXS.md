# SET FDXS - Micro DAX (Eurex)

- **Instrument** : FDXS (contrat courant) · **Graphe : 1 minute**
- **Usage** : ⚙️ **STRATÉGIE AUTO** - `ICT Silver Bullet Strategy` (forward-test Sim démo, puis réel si validé)
- **Backtest réf.** (2,5 ans, compte 50k) : **+35 613 $ · PF 1,26 · DD −12 204 $ (−24 %) · Sortino 1,46 · WR 36,9 % · RR 2,15**

## Réglages (ICT Silver Bullet Strategy)

### 1. Biais & Alignement
| Réglage | Valeur |
|---|---|
| TF Biais HTF (min) | **60** |
| TF Confirmation 1 (min) | **5** |
| TF Confirmation 2 (min) | **1** |
| EMA rapide / lente | **10 / 20** |
| Exiger l'alignement | ✅ ON |
| Sens des trades | **Both** |
| Filtre tendance Daily | ✅ ON |

### 2. Modèles d'entrée
| Réglage | Valeur |
|---|---|
| Entrée OTE (62-79 %) | ❌ **OFF** |
| Entrée FVG (post-sweep) | ❌ **OFF**  ← spécifique FDXS |
| Entrée retest EMA | ✅ **ON** |
| Déplacement min (ticks) | 20 |
| Expiration du setup (barres) | 30 |
| Exiger une cassure de structure (MSS) | ✅ ON |
| MSS : fenêtre de validité | 15 |

### 3. Stop / Take profit
| Réglage | Valeur |
|---|---|
| Buffer SL structurel (ticks) | 4 |
| TP1 (R) + BE | 2 |
| TP final (R) | 4 |
| Part sortie TP1 (%) | 50 |
| Trailing du runner | ✅ ON |
| Distance de trailing (R) | 2 |

### 4. Risque & Money
| Réglage | Valeur |
|---|---|
| Utiliser l'equity du compte | ✅ **ON** (sizing sur le vrai solde) |
| Risque / trade (%) | **1** |
| Risque après 1 perte (%) | **0,5** |
| Risque jusqu'au prochain (%) | **0,25** |
| Max positions | 3 |
| DD max / jour (%) | 5 |
| Contrats minimum | 1 |

### 5. Filtre horaire
| Restreindre aux fenêtres Silver Bullet | ✅ ON |

### 6. Visuel
| Dessiner les signaux / Alertes | ✅ / ✅ |

## Lancer le forward-test
1. Graphe **FDXS · 1 min**, vérifier que le prix **streame en direct**.
2. Clic droit → **Stratégies…** → `ICT Silver Bullet Strategy` → **Compte = Sim101** → appliquer ces réglages → **Activé** → OK.
3. Enregistrer un **modèle** « FDXS_forward » pour recharger.
4. Laisser tourner quelques semaines ; suivre le P&L dans Control Center → Stratégies.

> Pour t'approcher pile du backtest : décoche « Utiliser l'equity du compte » et mets **Taille de compte = 50000**.
