---
name: dev-quality-gates
description: Exécuter, interpréter et corriger les garde-fous qualité déterministes du dépôt (format, analyse, architecture, tests, couverture, mutation, l10n). À utiliser avant de conclure une tâche de code, quand la CI ou un hook échoue, ou pour auditer la qualité.
---

# Garde-fous qualité

Référence faisant foi : `docs/engineering/quality-gates.md` (tableau garde-fou / commande / lieu d'exécution).

## Commandes

```bash
scripts/check.sh --fast   # format + analyse + architecture (secondes)
scripts/check.sh --full   # + tests, couverture, l10n, mutation… (identique à la CI)
```

## Quand un garde-fou échoue

1. Lire le message jusqu'au bout ; corriger **la cause**.
2. Format : `dart format` sur les fichiers listés. Analyse : corriger le code, pas la règle.
3. Architecture : déplacer le code vers la bonne couche ou introduire une abstraction dans `domain` ; ne pas ajouter d'exception.
4. Couverture/mutation : ajouter ou renforcer des tests de comportement.
5. Fichiers générés : régénérer avec build_runner ; ne pas éditer.

## Interdits (contournements)

`git commit --no-verify`, `// ignore:` / `// ignore_for_file:` non justifiés par écrit, abaisser un seuil, exclure un fichier de la couverture, supprimer ou désactiver un test, modifier la configuration des garde-fous pour « faire passer ». Les hooks Claude Code bloquent les plus évidents ; la CI refait toutes les vérifications.

## Rapport

Donner la sortie réelle (commande, code de sortie, chiffres de couverture/mutation). Ne jamais déclarer « tout passe » sans l'avoir exécuté.
