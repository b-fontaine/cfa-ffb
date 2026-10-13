# Conception de séances — principes et contraintes

## Contraintes données par l'utilisateur

| Public | Durée totale | Statut |
|--------|--------------|--------|
| **Enfants** | **1 h 30 (90 min)** | Contrainte du projet. Absente des sources vérifiées. |
| **Adultes** | **2 h (120 min)** | Contrainte du projet. Absente des sources vérifiées. |

Les durées internes à la séance (échauffement, exercices, jeu…) ne figurent **dans aucune source** : elles sont `[Prop]` dans les modèles de ce dossier. Seules sont sourcées `[S]` l'**ordre des phases** et les **règles de conduite** (voir `../01-methode-pedagogique.md`).

## Invariants `[S]` à respecter dans toute séance générée

1. Phase 1 : **notion technique + initiation en groupe** (début de séance).
2. Phase 2 : **entraînement** avec résultats notés.
3. Phase 3 : **jeu** (fin de séance), lié au thème ; après les quantités de billes, partie à difficulté réduite.
4. **Plusieurs exercices différents**, chacun joué **2 fois au plus** dans la séance.
5. **Une seule notion principale** à introduire (éviter l'excès d'informations, cause de rejet chez le néophyte).
6. Ordre de progression des notions : voir `progression-par-cycles.md`.

## Fichiers

| Fichier | Contenu |
|---------|---------|
| `structure-type-seance.md` | Phases, ce qui est sourcé vs proposé, tableau minuté par public |
| `adaptation-public.md` | Différences enfants / adultes (tableau de décision) |
| `progression-par-cycles.md` | Enchaînement des notions sur plusieurs séances |
| `modele-seance.md` | Gabarit de livrable + liste de contrôle |
| `catalogue/FORMAT.md` | Format des séances du catalogue (14 techniques, 29 séances ; lues en lecture seule par l'application) |

## Index du catalogue (29 séances rédigées) et volumes de `[Prop]` à valider

Fichiers : `catalogue/NN-<id>.yaml` (format : `catalogue/FORMAT.md`). Contrôle transversal du 2026-10-13 : `fiches.dart --complete` vert, chaîne des rappels (`recall.reuse` vers une illustration de la séance précédente qui en reprend l'enseignement) et sources citées contrôlées sur les 29 fichiers.

**À valider par l'animateur, partout** (filtre « à valider » de l'application) : le thème, les défis ludiques (`playful`), la variante de jeu, la règle de lien avec la séance précédente, les adaptations, les poids et les minutes sont `[Prop]` dans les 29 séances ; ils ne sont pas répétés dans le tableau. Les exercices des blocs `posture` et `bille-fantome` (taux, consignes, schémas) sont aussi `[Prop]`.

**Reste à valider par séance** (contenu `[Prop]` de fond, hors éléments ci-dessus) :

| Séance (ordre) | Thème `[Prop]` | Rappel, théorie, initiation, exercices `[Prop]` (identifiants de section) | Jeu | Points ouverts (`uncertainties`) |
|---|---|---|---|---|
| `posture-1` (1) | Le tireur d'élite | rappel ; théorie : cible, gauchers, attaque ; exercices (bloc `[Prop]`) : e1, e2 | jeu n° 1 repris tel quel | 12 |
| `posture-2` (2) | Le tireur d'élite | théorie : distance ; exercices (bloc `[Prop]`) : e1, e2 | jeu n° 2 repris tel quel | 7 |
| `puissance-1` (3) | Les deux curseurs | théorie : curseur, mots-queue, ressort | jeu n° 3 repris tel quel | 9 |
| `puissance-2` (4) | Les deux curseurs | théorie : distances | jeu n° 4 repris tel quel | 10 |
| `bille-fantome-1` (5) | Le chasseur de fantômes | théorie : mot-fantome ; exercices (bloc `[Prop]`) : e1, e2 | adapté du jeu n° 1 | 7 |
| `bille-fantome-2` (6) | Le chasseur de fantômes | théorie : fantome-decalee, surface-distance ; exercices (bloc `[Prop]`) : e3, e4 | adapté du jeu n° 10 | 7 |
| `bille-pleine-1` (7) | Tir plein cœur | théorie : attaque | jeu n° 6 repris tel quel | 8 |
| `bille-pleine-2` (8) | Tir plein cœur | théorie : chevalets | jeu n° 6 repris tel quel | 6 |
| `demi-bille-1` (9) | Le partage du gâteau | théorie : mot-tangente | jeu n° 7 repris tel quel | 5 |
| `demi-bille-2` (10) | Le partage du gâteau | théorie : fantome-cote, loin, cadre, lire-erreur ; initiation : ini-7 | jeu n° 7 repris tel quel | 7 |
| `trois-quarts-1` (11) | Le chemin du milieu | théorie : mot-chemin, attaque | jeu n° 8 repris tel quel | 11 |
| `trois-quarts-2` (12) | Le chemin du milieu | théorie : meme-visee, cote-poche | jeu n° 8 repris tel quel | 8 |
| `quart-1` (13) | Au ras des billes | théorie : mot-bord ; initiation : ini-9 | jeu n° 9 repris tel quel | 9 |
| `finesse-1` (14) | L'art de frôler | théorie : mot-bord, puissance, lire-blanche | adapté du jeu n° 10 | 6 |
| `rebond-bande-1` (15) | Le ricochet | théorie : mots-bande, tete-relevee | jeu n° 13 repris tel quel | 10 |
| `rebond-bande-2` (16) | Le ricochet | théorie : angle-convention, deux-bandes ; initiation : ini-deux-bandes | jeu n° 13 repris tel quel | 8 |
| `rejet-naturel-1` (17) | Le virage à 45° | rappel ; théorie : de-cote, mot-replacement | jeu n° 14 repris tel quel | 10 |
| `rejet-naturel-2` (18) | Le virage à 45° | théorie : surface, virage-long, lire-chemin | jeu n° 14 repris tel quel | 10 |
| `coule-1` (19) | Dans le sillage | théorie : contraste, sillage | adapté du jeu n° 14 | 10 |
| `coule-2` (20) | Dans le sillage | théorie : mot-coule, lire-arret | adapté du jeu n° 14 | 9 |
| `coule-3` (21) | Dans le sillage | théorie : empoche, zone-lecture, annonce | adapté du jeu n° 14 | 9 |
| `carreau-1` (22) | La blanche se gare | théorie : gare, chevalet | jeu n° 14 repris tel quel | 7 |
| `carreau-2` (23) | La blanche se gare | théorie : meme-attaque, doser, lire-arret | adapté du jeu n° 14 | 6 |
| `angle-droit-1` (24) | Le jeu de l'équerre | théorie : mot-equerre | jeu n° 14 repris tel quel | 9 |
| `angle-droit-2` (25) | Le jeu de l'équerre | théorie : replacer, quantites, surface, lire | adapté du jeu n° 14 | 10 |
| `retro-1` (26) | Le boomerang | théorie : regler-retour, mot-boomerang | adapté du jeu n° 14 | 11 |
| `retro-2` (27) | Le boomerang | théorie : mot-boomerang | adapté du jeu n° 14 | 8 |
| `retro-3` (28) | Le boomerang | théorie : zone-arrivee, deux-arrivees | adapté du jeu n° 14 | 7 |
| `retro-4` (29) | Le boomerang | théorie : viser-zone, zone-puissance | adapté du jeu n° 14 | 8 |

Volumes : 29 séances sur 29 « à valider » au sens de `FORMAT.md` § 5.3 (chacune a au moins une section de théorie `[Prop]`) ; 59 sections de théorie, 3 éléments d'initiation, 2 rappels et 8 exercices (blocs `posture` et `bille-fantome`) `[Prop]` ; 12 jeux adaptés (`adapted: true`, `src: Prop`) : `bille-fantome-1`, `bille-fantome-2`, `finesse-1`, `coule-1` à `coule-3`, `carreau-2`, `angle-droit-2`, `retro-1` à `retro-4` ; 17 jeux repris tels quels `[S]` (la règle de lien et la variante restent `[Prop]`). Chaque fichier détaille ses `[Prop]` et ses hypothèses dans `uncertainties` (244 points au total).

Thèmes : un nom par technique, tous distincts (14 noms). « Le ricochet » reste réservé au rebond sur bande ; le rejet naturel est « Le virage à 45° » (contrôle du 2026-10-13).

## Sorties

Les séances générées sont enregistrées dans `/seances/` (voir `/seances/README.md`).
