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

## Sorties

Les séances générées sont enregistrées dans `/seances/` (voir `/seances/README.md`).
