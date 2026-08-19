# Backtests Silver Bullet v2 - DE30 et XAUUSD

Date d'exécution : 9 août 2026

## Configuration commune

- Expert : \`ICT_SilverBullet_Strategy.ex5\`
- Timeframe d'exécution : M5
- Période : 2 janvier 2026 au 8 août 2026
- Modèle MT5 : ticks réels
- Qualité d'historique annoncée par MT5 : 100 % ticks réels
- Dépôt initial : 100 000 USD
- Levier : 1:100
- Biais et stacking obligatoires : D1 + H1 + M5 + M1
- Déclencheurs activés : FVG et retest EMA
- OTE désactivé
- Fenêtres New York et DST automatique activés
- TP1 : 2 R sur 50 % du volume
- Objectif final : 4 R
- Trailing : 2 R

## Résultats

| Symbole | Barres | Ticks | Setups créés | Trades | Profit net | Drawdown |
|---|---:|---:|---:|---:|---:|---:|
| DE30 | 41 702 | 16 929 881 | 2 | 0 | 0,00 USD | 0,00 % |
| XAUUSD | 42 572 | 61 795 609 | 6 | 0 | 0,00 USD | 0,00 % |

Les deux tests sont techniquement terminés sans erreur, mais aucune séquence complète n'a atteint l'état d'entrée. Le profit factor affiché à 0 par MT5 n'a donc aucune valeur statistique : il n'y a ni gain ni perte à analyser.

## Diagnostic du journal

DE30 :

- 2 setups LONG ont été créés, le 3 juillet et le 5 août 2026 ;
- 6 346 purges potentielles ont été rejetées par le filtre combiné « fenêtre, biais, capacité ou liquidité » ;
- aucun setup n'a complété toute la séquence jusqu'à l'ordre marché.

XAUUSD :

- 6 setups ont été créés : 4 LONG et 2 SHORT ;
- 7 098 purges potentielles ont été rejetées par le même filtre combiné ;
- aucun setup n'a complété toute la séquence jusqu'à l'ordre marché.

Le résultat montre surtout que la combinaison actuelle des contraintes est extrêmement sélective sur cette période. Il ne permet pas encore d'évaluer la rentabilité, le risque, les sorties ou le taux de réussite.

## Fichiers

- [Rapport MT5 DE30](ICT_SB_DE30_M5_20260102_20260808.htm)
- [Configuration DE30](ict_sb_de30_m5.ini)
- [Rapport MT5 XAUUSD](ICT_SB_XAUUSD_M5_20260102_20260808.htm)
- [Configuration XAUUSD](ict_sb_xauusd_m5.ini)

## Limite de données

Le premier essai avait demandé une période commençant en janvier 2025. Le serveur Exness utilisé ne fournit toutefois les ticks réels de DE30 qu'à partir du 2 janvier 2026 et ceux de XAUUSD qu'à partir du 1er janvier 2026. La période de référence a donc été ramenée au 2 janvier 2026 afin que les deux actifs soient comparés uniquement sur leur couverture commune en ticks réels.
