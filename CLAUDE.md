@AGENTS.md

# Spécifique à Claude Code

- Skills : `.claude/skills` pointe vers `.agents/skills` (source canonique, partagée avec les autres outils). Ne pas dupliquer.
- Sous-agents : `.claude/agents` pointe vers `.agents/agents`.
- Hooks (`.claude/settings.json`) : formatage automatique après édition, blocage des modifications de fichiers générés / de `docs/sources/` / de la configuration des garde-fous, et vérification rapide à l'arrêt. Voir `.claude/hooks/`.
- Pour toute séance : invoquer `seance-planifier` plutôt que d'improviser ; pour toute feature : `dev-feature`.
- Faire relire par `relecteur-pedagogique` (séances) ou `architecte-fsd` + `testeur-bdd` (code) dans un contexte séparé avant de conclure.
- Si un hook bloque une action, corriger la cause ; ne pas chercher à le contourner.
