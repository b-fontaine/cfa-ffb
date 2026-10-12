---
name: seance-adapter
description: Adapter un exercice, un jeu ou une séance existante à un autre public (enfants 90 min ↔ adultes 120 min) en conservant le contenu technique sourcé. À utiliser quand on demande de « passer en version enfants/adultes » ou d'alléger/densifier une séance.
---

# Adapter une séance à un public

## Procédure

1. Identifier le public d'origine et la cible ; lire `docs/knowledge/05-seances/adaptation-public.md`.
2. Conserver : notion, fiches sources, taux de réussite sourcés, ordre notion → entraînement → jeu.
3. Modifier uniquement : dosage d'explication, nombre d'exercices, poids du jeu, formulation, minutage, corrections.
4. Recalculer le minutage pour que la somme = durée cible (90 ou 120) ; mettre à jour `public` et `duree_minutes` dans le front matter.
5. Toute modification non sourcée reçoit `[Prop]` ; le seul écart enfants/adultes sourcé est la **position de la blanche à la casse**.
6. Si un taux de réussite est abaissé/relevé, garder la valeur sourcée à côté et marquer l'écart `[Prop]`.
7. Valider : `dart run scripts/validate_seances.dart`, puis relecture par `relecteur-pedagogique`.

## Sortie

Nouveau fichier de séance (ne pas écraser l'original) + tableau « avant / après » des changements avec leur statut `[S]` ou `[Prop]`.
