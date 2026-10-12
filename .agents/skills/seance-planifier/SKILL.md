---
name: seance-planifier
description: Produire une séance de billard (Blackball, niveau 1) pour un public enfants (90 min) ou adultes (120 min), sourcée sur les fiches fédérales. À utiliser dès qu'on demande de préparer, imaginer ou concevoir une séance, un cours ou un atelier de billard.
---

# Planifier une séance

## Entrées à obtenir (demander si absent)

1. **Public** : `enfants` (90 min) ou `adultes` (120 min). Jamais d'autre durée sans accord explicite.
2. **Notion principale** (une seule) ; sinon la déduire de `docs/knowledge/05-seances/progression-par-cycles.md` et de la séance précédente.
3. Optionnel : effectif, matériel, niveau du groupe, séance précédente.

## Procédure

1. Lire `docs/knowledge/00-provenance-et-fiabilite.md` puis `docs/knowledge/05-seances/README.md` et `structure-type-seance.md`.
2. Lire la fiche technique de la notion dans `docs/knowledge/02-techniques/` et les fiches `initiation.md`, `entrainement.md` (ou `catalogue-entrainement.yaml`), `jeux.md`.
3. Choisir : 1 notion + initiation, **au moins 2 exercices d'entraînement différents** (chacun ≤ 2 passages), 1 jeu lié à la notion (ou partie à difficulté réduite si les quantités sont acquises).
4. Appliquer `adaptation-public.md` pour le public ciblé.
5. Minuter selon `structure-type-seance.md` : la **somme doit valoir exactement 90 ou 120**.
6. Rédiger dans `seances/AAAA-MM-JJ-<public>-<notion>.md` avec le gabarit `modele-seance.md` (front matter obligatoire).
7. Étiqueter chaque ligne du déroulé `[S]`, `[FFB]`, `[Web]` ou `[Prop]` ; reprendre les taux de réussite tels quels.
8. Lancer `dart run scripts/validate_seances.dart` ; corriger jusqu'au vert.
9. Déléguer la relecture à l'agent `relecteur-pedagogique` (contexte séparé) avant de conclure.

## Interdits

- Inventer un exercice, un taux ou un nombre de séances.
- Présenter une proposition `[Prop]` comme règle fédérale.
- Modifier `docs/sources/`.
- Mélanger des notions du carambole ou du billard américain au Blackball sans le signaler.

## Résultat attendu

Un fichier de séance valide + un résumé de 5 lignes : public, notion, exercices retenus (avec fiches), jeu, points `[Prop]` à valider.
