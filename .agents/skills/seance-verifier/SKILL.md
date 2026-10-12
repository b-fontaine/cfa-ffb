---
name: seance-verifier
description: Contrôler une séance de billard déjà rédigée (durée, ordre des phases, sources, taux de réussite, adaptation au public). À utiliser avant de livrer ou valider une séance, ou pour auditer les fichiers de `seances/`.
---

# Vérifier une séance

## Contrôles déterministes (obligatoires)

```bash
dart run scripts/validate_seances.dart            # tous les fichiers de seances/
dart run scripts/validate_seances.dart <dossier>  # un dossier précis
```

Vérifie : front matter, public ↔ durée (enfants 90, adultes 120), déroulé contigu 0 → durée, étiquette de source par ligne, ordre notion → entraînement → jeu.

## Contrôles de contenu (relecture)

Comparer avec les sources, pas avec la mémoire :

- [ ] Une seule notion principale.
- [ ] Chaque exercice existe dans `docs/knowledge/03-exercices/` ; taux de réussite identiques.
- [ ] ≥ 2 exercices d'entraînement différents, aucun > 2 passages.
- [ ] Jeu correspondant à la notion (`jeux.md`) ou partie à difficulté réduite.
- [ ] Prérequis cohérents avec `progression-par-cycles.md`.
- [ ] Adaptation au public conforme à `adaptation-public.md` ; `[Prop]` signalé.
- [ ] Aucune règle non sourcée présentée comme fédérale ; aucune transposition de discipline cachée.
- [ ] Première séance posture/coup de queue : explications dosées (risque de rejet).

## Rapport

Liste numérotée : sévérité (bloquant / à corriger / suggestion), ligne concernée, source qui contredit, correction proposée. Ne pas corriger soi-même la séance relue : renvoyer à l'auteur.
