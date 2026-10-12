---
name: seance-cycle
description: Planifier une progression de plusieurs séances (cycle) pour un public enfants ou adultes, en suivant l'ordre pédagogique des fiches fédérales. À utiliser pour un programme de saison, un trimestre ou « les N prochaines séances ».
---

# Planifier un cycle de séances

## Procédure

1. Entrées : public (90 ou 120 min), nombre de séances disponibles, point de départ (notion déjà acquise).
2. Lire `docs/knowledge/05-seances/progression-par-cycles.md` et `docs/knowledge/03-exercices/entrainement.md` (séances conseillées par notion).
3. Construire le plan : une ligne par séance = notion principale + rappel + jeu. Respecter l'ordre A → B → C → D.
4. Si le nombre de séances disponibles est inférieur au minimum conseillé, **dire ce qui est sacrifié** plutôt que de compresser en silence ; si supérieur, proposer rappels et parties à difficulté réduite.
5. Ne pas dépasser une notion principale par séance ; prévoir une séance « casse » optionnelle (une séance entière possible selon le mémento).
6. Écrire le plan dans `seances/cycle-<public>-<debut>.md` : tableau `# | notion | rappel | jeu | objectif de réussite`, avec étiquettes de source.
7. Générer les séances détaillées avec `seance-planifier` à la demande, pas toutes d'emblée.

## Interdits

Réordonner les cycles sans justification ; promettre un niveau (bronze…) dont l'épreuve n'est pas dans les sources.
