# Provenance et fiabilité des connaissances

Toute affirmation de cette base porte une étiquette de provenance. En cas de conflit, **la source de rang le plus élevé gagne**.

| Étiquette | Rang | Source | Fiabilité |
|-----------|------|--------|-----------|
| `[S]` | 1 | Les 5 PDF fournis dans `docs/sources/` (Mémento animateur FFB/DTN, édition 2023, niveau technique 1, option « billards à poches », jeu Blackball) | Référence. Fait foi. |
| `[FFB]` | 2 | Site ffbillard.com et documents hébergés par la fédération (cahiers techniques, pages de formation) | Officiel mais parfois ancien (2002, 2005, 2013, 2017, 2022). |
| `[Web]` | 3 | Autres sites (ligues, dépôts GitHub, blogs) | Indicatif, jamais prioritaire. |
| `[U]` | 0 | Décision explicite de l'animateur (utilisateur du projet), datée dans `08-lacunes-et-questions-ouvertes.md` ou le document concerné | Contrainte de projet, prime sur `[Prop]` ; ne pas la présenter comme règle fédérale. |
| `[Prop]` | — | Proposition pédagogique rédigée pour ce projet, **non sourcée** | À valider par l'animateur. Ne jamais la présenter comme une règle fédérale. |

## Règles d'usage pour les agents

1. Une notion technique, un exercice, un taux de réussite ou un nombre de séances doivent venir d'une source `[S]`. Si ce n'est pas le cas, l'étiquette `[Prop]` est obligatoire.
2. Les durées de séance (1 h 30 enfants, 2 h adultes) sont **une contrainte donnée par l'utilisateur**, pas une prescription fédérale : aucune source vérifiée ne les contient. Voir `05-seances/`.
3. Les sources fournies traitent le **Blackball** (billard à poches « anglais » avec une bille blanche plus petite que les autres). Les notions valables pour le billard américain, le snooker ou la carambole ne doivent pas être transposées sans le dire.
4. Ne jamais inventer un exercice « officiel » : un exercice nouveau est étiqueté `[Prop]` et dérive d'un exercice existant cité.

## Ce qui a été vérifié sur Internet

Un workflow de recherche a extrait 81 affirmations, en a soumis 25 à une vérification contradictoire (3 votes) : 23 confirmées, 2 réfutées. Détails et limites dans `06-contexte-federal.md` et `08-lacunes-et-questions-ouvertes.md`.

Affirmations **réfutées** (ne pas utiliser) :

- « Le diplôme d'animateur cible les compétiteurs jeunes avec les niveaux billard d'argent (–15 ans) et d'or (–18 ans), environ une douzaine de séances par niveau » (vote 1-2).
- « La formation DFI = cinq jours obligatoires suivis d'un jour d'évaluation devant jury » (vote 1-2). Voir `06-contexte-federal.md` pour la formulation retenue.

## Écarts connus entre sources

- Fiche technique n° 6 (trois-quarts) : « la bille blanche confère les trois quarts de son énergie » ; fiche initiation correspondante : « transfère **deux fois plus** d'énergie qu'elle n'en conserve » (soit deux tiers). Les deux formulations sont dans les sources `[S]` ; ne pas les harmoniser, citer la fiche utilisée.
- Fiche technique n° 9 (rebond) : le texte dit que plus le coup est puissant, plus l'angle de rebond « se referme » ; la légende du schéma note « angle d'arrivée < angle de rebond ». Le texte est retenu, mais l'ambiguïté est à signaler à l'animateur.
- Fiche entraînement « Le rejet naturel » : le bloc apparaît **deux fois** dans le PDF, avec « Nombre de séances : 2 » puis « 1 à 2 » et des schémas différents. Voir `03-exercices/entrainement.md`.
- Fiche résultats : le PDF présente 5 essais ; l'exemple du mémento en présente 6.
- **Blocs d'entraînement ajoutés hors source `[Prop]`** : le PDF d'entraînement n'a pas de bloc pour la posture ni pour la bille fantôme. Le catalogue structuré (`03-exercices/catalogue-entrainement.yaml`) en contient deux, `posture` et `bille-fantome`, marqués `source: Prop` (bloc et exercices) : exercices adaptés de fiches d'initiation, de jeux et techniques `[S]`, taux de réussite et nombre de séances `[Prop]`, mise en place dans `03-exercices/diagrammes/proposition/`. Décision de l'animateur : « s'il n'y a pas de bloc d'entraînement, il faut en créer ». Ils ne figurent ni dans les 34 pages du PDF ni dans les totaux `[S]`.
