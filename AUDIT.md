# Audit complet de la solution ICT MQL5

Date de l'audit : 9 août 2026  
Périmètre : cinq programmes MQL5, presets, configurations de backtest, documentation et dashboard HTML.

## Verdict

La solution est techniquement riche et bien documentée, mais elle n'est pas encore suffisamment robuste pour du trading live autonome. Elle doit être considérée comme un prototype avancé de recherche et de forward test, et non comme une version de production.

L'audit est statique : 4 213 lignes MQL5 ont été examinées. Aucun compilateur MetaEditor/Wine ni environnement broker n'étant disponible dans l'environnement d'audit, les fichiers `.mq5` n'ont pas été recompilés et les backtests n'ont pas été rejoués.

## Synthèse des risques

| Domaine | Évaluation |
|---|---|
| Couverture fonctionnelle | Bonne |
| Fidélité des indicateurs | Moyenne |
| Exécution des ordres | Faible |
| Protection du capital | Faible à moyenne |
| Résilience aux redémarrages | Faible |
| Maintenabilité | Moyenne |
| Observabilité et journal | Moyenne |
| Reproductibilité des backtests | Faible |
| Cybersécurité | Correcte |
| Aptitude au live autonome | Insuffisante |

## Problèmes critiques

### 1. Structure OTE peut modifier ou fermer la mauvaise position

L'EA sélectionne d'abord une position par symbole et magic, mais ferme et modifie ensuite par symbole :

- sélection par magic : `ICT_Structure_OTE_EA.mq5:370` ;
- fermeture par symbole : `ICT_Structure_OTE_EA.mq5:380` ;
- modification par symbole : `ICT_Structure_OTE_EA.mq5:388` et `:393`.

En compte hedging, `PositionClose(symbol)` et `PositionModify(symbol)` ciblent la position ayant le ticket le plus faible, pas nécessairement celle du magic `260709`.

Conséquence possible : fermeture d'un trade manuel ou modification du SL d'un autre EA.

Correction requise : conserver le ticket de la position sélectionnée et utiliser exclusivement les variantes par ticket.

Références officielles :

- <https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionclose>
- <https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionmodify>

### 2. Les coupe-circuits du Risk Manager laissent vivre les ordres en attente

`CloseAllPositions()` ne parcourt que `PositionsTotal()` (`TA_RiskManager.mq5:293`). Aucun ordre pending n'est supprimé.

Après une limite journalière ou un drawdown maximal :

1. les positions sont fermées ;
2. les ordres différés restent chez le broker ;
3. ils peuvent se déclencher après la fermeture forcée.

De plus, `dayFlatDone` et `ddFlatDone` sont positionnés avant la tentative de fermeture (`TA_RiskManager.mq5:857-868`). Si une fermeture échoue, le moteur ne retente plus avant le prochain reset ou redémarrage.

Correction requise : annuler les ordres en attente, fermer les positions, vérifier les retcodes, puis continuer à contrôler que le compte est réellement flat.

### 3. Silver Bullet dimensionne le trade autour d'un prix non exécuté

Le signal calcule un prix théorique à partir de la bougie précédente, du FVG, de l'OTE ou de l'EMA (`ICT_SilverBullet_Strategy.mq5:504-544`). Ce prix sert au calcul du volume, du risque R, de TP1, du TP final et du break-even.

L'ordre est toutefois envoyé au marché avec `price=0` (`ICT_SilverBullet_Strategy.mq5:358-364`). MetaTrader utilise alors l'Ask courant pour un achat et le Bid courant pour une vente.

Un gap entre le signal et l'ouverture réelle peut produire :

- un risque réel différent du risque demandé ;
- un TP trop proche ou placé du mauvais côté ;
- un ordre rejeté ;
- un R journalisé incorrect ;
- une divergence entre signal, backtest et live.

Correction requise : utiliser un ordre limit/stop au prix du modèle ou récupérer `trade.ResultPrice()` et recalculer volume, R et objectifs depuis le fill réel.

Référence officielle : <https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradebuy>

### 4. Les EA ne récupèrent pas correctement leur état après redémarrage

Dans Structure OTE, `g_posR` reste à zéro après redémarrage. La position est détectée, mais le break-even devient inactif (`ICT_Structure_OTE_EA.mq5:383`).

Dans Silver Bullet, les setups et rattachements `posId`, TP1, core, runner et trailing ne vivent qu'en mémoire. Après redémarrage :

- la position broker reste ouverte ;
- le core n'est plus géré ;
- le passage au break-even ne se produit plus ;
- le trailing n'est plus exécuté ;
- la clôture ne met plus à jour le niveau de risque dynamique.

Le Risk Manager persiste les plans de TP partiels, mais pas son registre de risque initial.

Correction requise : reconstruire l'état depuis les positions, commentaires, magic numbers, SL/TP, historique et variables globales dans `OnInit()`.

## Problèmes de sévérité élevée

### 5. Les résultats serveur des opérations de trading sont rarement vérifiés

De nombreux appels considèrent le booléen de `CTrade` comme une confirmation d'exécution. Un retour `true` signifie pourtant seulement que les structures de requête ont passé les contrôles de base. Il faut également vérifier `ResultRetcode()`.

Conséquences observables :

- BE marqué comme effectué même si `PositionModify` échoue ;
- trailing interne avancé même si le SL broker ne bouge pas ;
- TP1 marqué comme pris même si la fermeture partielle échoue ;
- fermeture forcée considérée comme terminée sans confirmation.

Exemple : `ICT_SilverBullet_Strategy.mq5:563-597`.

Référence officielle : <https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade>

### 6. Le lot minimum peut dépasser le risque autorisé

Structure OTE force le lot minimum lorsque le volume calculé est trop faible (`ICT_Structure_OTE_EA.mq5:193-200`). Silver Bullet fait la même chose (`ICT_SilverBullet_Strategy.mq5:232-241`).

Sur un petit compte, un actif volatil ou un SL large, le risque réel peut dépasser largement `InpRiskPct`.

Correction requise : refuser l'ordre ou demander explicitement l'autorisation de dépasser le risque. Le Risk Manager applique déjà la politique plus sûre en retournant zéro.

### 7. La zone OTE n'est pas toujours réellement touchée

Structure OTE ne vérifie qu'une seule borne :

- long : `low <= zoneTop` ;
- short : `high >= zoneBottom`.

Voir `ICT_Structure_OTE_EA.mq5:337-357`.

Une bougie ayant entièrement gapé au-delà de la zone peut donc être considérée comme un tap. Il faut tester l'intersection complète :

```text
high >= zoneBottom && low <= zoneTop
```

### 8. `InpOteHigh=0.79` n'est jamais utilisé par Silver Bullet

Le paramètre est déclaré dans `ICT_SilverBullet_Strategy.mq5:59`, mais la logique d'entrée utilise seulement `InpOteLow` et `InpOteSweet` (`:516-534`).

Le modèle présenté comme « OTE 62-79 % » accepte tout retracement dépassant 62 %, sans borne profonde à 79 %. L'indicateur Signals reproduit le comportement et ne possède pas de paramètre `InpOteHigh`.

Il existe donc une divergence directe entre la stratégie annoncée, ses paramètres et son implémentation.

### 9. Le biais D1 de Structure OTE mélange deux bougies

Le code copie deux valeurs EMA à partir du shift zéro, puis lit `ef[0]` (`ICT_Structure_OTE_EA.mq5:136-144`). `CopyBuffer` place l'élément le plus ancien au début du tableau. Avec deux valeurs, `ef[0]` représente la valeur précédente, tandis que le close utilisé est celui de la bougie D1 courante.

La règle compare vraisemblablement le close D1 courant aux EMA D1 précédentes. Cette erreur peut modifier le classement A+ et les résultats de backtest.

Référence officielle : <https://www.mql5.com/en/docs/series/copybuffer>

### 10. L'état A+ de Structure OTE est figé trop tôt

`g_armAplus` est calculé à l'armement de la zone (`ICT_Structure_OTE_EA.mq5:291-309`). L'entrée peut arriver plusieurs bougies plus tard sans nouvelle vérification du biais D1.

Un setup reste donc A+ même si le biais s'est inversé. Il faut définir explicitement si le grade retenu doit être celui de l'armement ou celui de l'entrée.

### 11. Le Risk Manager perd la mesure de R après 200 positions

Le registre `trkId/trkRisk/trkPct` est limité à 200 entrées et n'est jamais purgé (`TA_RiskManager.mq5:437-468`). Après 200 positions observées :

- les nouveaux risques initiaux ne sont plus enregistrés ;
- le R réalisé tombe à zéro ;
- les statistiques de session deviennent fausses.

Ce registre n'est pas persisté. Un redémarrage produit le même problème pour les positions déjà ouvertes.

### 12. Le grade journalisé est celui de la clôture

Le pourcentage est partiellement mémorisé, mais pas le grade. À la clôture, le journal appelle directement `GradeTxt()` (`TA_RiskManager.mq5:1402-1408`).

Si l'utilisateur passe de A+ à CT avant la clôture, l'ancien trade est journalisé CT. Les trades externes reçoivent également le grade actif au moment de leur fermeture.

### 13. Identifiant et ticket de position sont confondus

Le journal récupère `DEAL_POSITION_ID`, puis le passe à `PositionSelectByTicket` (`TA_RiskManager.mq5:1350-1356`).

Le ticket et l'identifiant sont généralement identiques à l'ouverture, mais le ticket peut changer lors d'opérations serveur alors que l'identifiant reste stable.

Conséquence possible : une sortie partielle peut être prise pour une clôture complète et journalisée prématurément.

Références officielles :

- <https://www.mql5.com/en/docs/constants/tradingconstants/positionproperties>
- <https://www.mql5.com/en/docs/trading/positionselectbyticket>

### 14. Le cap d'exposition ignore les positions sans SL

Le calcul saute explicitement toute position sans stop (`TA_RiskManager.mq5:243-259`). Une position non protégée représente pourtant le risque le plus élevé.

Le système devrait bloquer les nouvelles entrées lorsqu'une position sans SL existe, l'afficher comme risque non mesurable, ou appliquer une convention configurée.

### 15. Le mode hedging requis n'est pas validé

Silver Bullet dépend de plusieurs positions simultanées et de `PositionClosePartial`, mais `OnInit()` ne contrôle pas `ACCOUNT_MARGIN_MODE`.

Sur un compte netting, les setups fusionnent et le rattachement `setup -> position` devient invalide.

Correction requise : retourner `INIT_FAILED` avec un message explicite lorsque le compte n'est pas hedging.

## Problèmes de sévérité moyenne

### 16. La limite journalière Silver Bullet ne mesure que le réalisé

Le verrou repose sur `g_dayRealized`, mis à jour uniquement lors de la fermeture complète (`ICT_SilverBullet_Strategy.mq5:292-315`). Les pertes flottantes ne comptent pas.

Trois positions peuvent donc dépasser la limite en équité sans bloquer de nouvelles entrées avant leur fermeture.

Les programmes n'utilisent pas non plus la même définition de journée :

- Silver Bullet : minuit New York ;
- Structure OTE : minuit New York ;
- Risk Manager : 18:00 New York.

### 17. Les indicateurs ne fixent pas le sens des tableaux `OnCalculate`

TopDown et Signals supposent que `time[0]` est l'élément le plus ancien et parcourent les tableaux dans ce sens, sans faire `ArraySetAsSeries(..., false)` sur les tableaux reçus.

MetaQuotes recommande de fixer explicitement cette propriété afin de ne pas dépendre des valeurs par défaut.

Référence officielle : <https://www.mql5.com/en/docs/event_handlers/oncalculate>

### 18. Les killzones TopDown utilisent une soustraction de dates `YYYYMMDD`

Le filtrage se trouve dans `ICT_TopDown_Confluence.mq5:832-847`.

Exemple :

```text
20260801 - 20260731 = 70
```

Deux jours consécutifs traversant un changement de mois peuvent être considérés comme distants de 70 jours. Les killzones, macros et Asian Boxes historiques peuvent disparaître autour des changements de mois ou d'année.

Correction requise : comparer des `datetime` ou compter les jours calendaires.

### 19. Les anciens labels OTE A+ utilisent le biais actuel

Pendant le recalcul historique, `DrawOte()` appelle `StackState()` sans date historique (`ICT_TopDown_Confluence.mq5:876-910`). Tous les anciens OTE sont donc gradés à partir du biais actuel, et non de celui qui existait lors de leur formation.

### 20. Signals reconstruit ses objets de session à chaque calcul

`RebuildLanes()` supprime puis recrée les killzones et macros à chaque `OnCalculate` (`ICT_SilverBullet_Signals.mq5:795`). `OnCalculate` pouvant être appelé à chaque tick, cela peut provoquer charge CPU, clignotements et latence.

La reconstruction devrait être limitée à une nouvelle bougie, un changement de jour, de graphique ou d'échelle.

### 21. L'offset broker de Signals n'est détecté qu'à l'initialisation

TopDown recalcule régulièrement l'offset serveur. Signals ne le calcule que dans `OnInit`. Si le broker change d'offset DST pendant que l'indicateur reste chargé, les fenêtres peuvent rester décalées jusqu'au rechargement.

### 22. Les handles d'indicateurs ne sont pas toujours libérés

TopDown ne libère pas ses handles EMA dans `OnDeinit`. Le Risk Manager ne libère pas son handle ATR.

MT5 nettoie généralement les ressources lors de la destruction du programme, mais une libération explicite reste préférable pendant les cycles de rechargement.

### 23. Aucun contrôle de cohérence des inputs

Les programmes n'empêchent pas les configurations telles que :

- EMA rapide supérieure ou égale à EMA lente ;
- risque négatif ou excessif ;
- TP1 supérieur ou égal au TP final ;
- OTE shallow supérieur ou égal à OTE deep ;
- longueur de pivot invalide ;
- période ATR ou nombre de TP incohérent ;
- heure de flat hors plage.

Ces contrôles devraient être réalisés dans `OnInit()` avec `INIT_PARAMETERS_INCORRECT`.

## Reproductibilité et validation

### Backtests non totalement reproductibles

Les fichiers `.ini` Structure OTE ne contiennent pas `[TesterInputs]`, alors que `REPORTS.md` explique que MT5 peut réutiliser les derniers paramètres du testeur. Le preset `.set` existe, mais les `.ini` ne le référencent pas explicitement.

Pour Silver Bullet, les presets DE30/XAUUSD et le script `scratchpad/scan_markets.sh` mentionnés dans le README sont absents.

Les rapports MT5 bruts ne sont pas versionnés. Il est impossible de confirmer indépendamment :

- les paramètres réellement utilisés ;
- les données broker ;
- les spreads ;
- les résultats détaillés ;
- la séquence exacte des sorties partielles.

### Modèle de backtest insuffisant pour certaines sorties

Les configurations utilisent le modèle `1-minute OHLC`, alors que les stratégies comportent sorties partielles, break-even, trailing et plusieurs niveaux potentiellement touchés dans la même bougie.

Le modèle OHLC ne permet pas toujours de déterminer l'ordre intrabar entre TP, SL et retracement. Les résultats devraient être confirmés en `Every tick based on real ticks`.

### Fichiers de statistiques sujets aux écrasements

Structure OTE écrit toujours dans `ict_bt_stats.txt`.

Silver Bullet construit son nom de fichier à partir d'une partie seulement des paramètres. Deux passes différant sur un paramètre absent du nom peuvent écraser le même CSV malgré le commentaire « unique par config ».

### Documentation désynchronisée

- `dashboard.html` affiche encore PF `1,39`, contre `1,463` dans le rapport actuel ;
- README annonce TopDown v2.5 et Risk Manager V2.0, alors que les propriétés MQL5 déclarent `1.00` ;
- le dashboard nécessaire au Risk Manager est absent ;
- plusieurs chemins `../pine`, `../ninjatrader` et `scratchpad` ne sont pas autonomes ;
- un seul commit initial contient l'intégralité de la solution.

## Architecture et maintenabilité

### Points positifs

- séparation claire par programme MT5 ;
- commentaires métier abondants ;
- magic numbers distincts ;
- préfixes d'objets cohérents ;
- nettoyage des objets graphiques ;
- calcul des volumes utilisant tick value et tick size ;
- logique majoritairement fondée sur les bougies fermées ;
- persistance réussie des plans de sorties partielles du Risk Manager.

### Faiblesses

- fichiers monolithiques ;
- état global mutable abondant ;
- trois implémentations différentes de l'heure New York et du DST ;
- duplication presque complète entre Silver Bullet Strategy et Signals ;
- dérive déjà visible entre l'EA et l'indicateur ;
- aucune bibliothèque commune `.mqh` ;
- aucune couche dédiée à l'exécution robuste ;
- aucune machine d'état persistante pour les positions ;
- aucun test automatisé.

Architecture cible recommandée :

```text
Signal Engine
    |
    v
Position Plan
    |
    v
Risk / Sizing
    |
    v
Execution Adapter
    |
    v
Persistent Position State
    |
    v
Journal / Telemetry
```

L'EA et l'indicateur Silver Bullet devraient consommer un moteur de signal partagé.

## Sécurité

Le risque principal est financier, pas informatique.

Points rassurants :

- aucun secret dans le dépôt ;
- aucun appel réseau ;
- aucun `WebRequest` ;
- fichiers écrits seulement dans les zones MT5 ;
- magic numbers utilisés dans la plupart des opérations automatiques.

Points à surveiller :

- `shell32.dll` est importé par le Risk Manager ;
- le bouton `DASH` ouvre un fichier local dépendant d'un template externe ;
- `CLOSE ALL` est immédiat et sans confirmation ;
- les données CSV sont transformées en JavaScript sans échappement robuste ;
- le verrou FTMO-like peut être contourné volontairement par double clic.

## Plan de remédiation

### P0 — avant tout live

1. Utiliser exclusivement les tickets pour fermer et modifier les positions.
2. Vérifier tous les `ResultRetcode()` et ne modifier l'état interne qu'après succès serveur.
3. Rendre le coupe-circuit vérifié et idempotent : positions fermées, pendings supprimés, nouvelles entrées réellement interdites.
4. Recalculer Silver Bullet depuis le fill réel ou utiliser des ordres au prix du modèle.
5. Restaurer les plans et états de position après redémarrage.
6. Refuser le lot minimum lorsqu'il dépasse le risque autorisé.

### P1 — avant une nouvelle campagne de backtest

1. Corriger les intersections OTE et utiliser la borne 79 %.
2. Corriger le biais D1 et son appel à `CopyBuffer`.
3. Revalider le biais A+ au moment explicitement choisi.
4. Vérifier le mode hedging au démarrage.
5. Rejouer les tests en vrais ticks avec configurations versionnées.
6. Tester les rejets broker, fermetures partielles, freeze levels et reconnexions.

### P2 — fiabilité fonctionnelle

1. Remplacer le registre Risk Manager limité à 200 trades.
2. Persister le grade, le risque et l'état de chaque position.
3. Corriger la comparaison de dates TopDown.
4. Calculer le grade A+ historique à la date du setup.
5. Uniformiser le DST et la définition de la journée de trading.
6. Fixer explicitement le sens des tableaux `OnCalculate`.

### P3 — industrialisation

1. Extraire des modules `.mqh` communs.
2. Ajouter des tests unitaires de calcul et des scénarios Strategy Tester.
3. Versionner presets, rapports bruts et métadonnées broker.
4. Ajouter un journal structuré des demandes et réponses serveur.
5. Synchroniser versions, README, dashboard et rapports.

## Conclusion

Les idées de stratégie, les outils graphiques et l'expérience utilisateur sont avancés. Les garanties d'exécution et de protection du compte restent toutefois insuffisantes.

Les problèmes critiques relatifs au ciblage des positions, aux ordres pending, au prix d'exécution Silver Bullet et à la reprise après redémarrage suffisent à déconseiller le live autonome dans l'état actuel.
