---
name: dev-feature
description: Créer ou modifier une feature de l'application Flutter en respectant Clean Architecture + Feature-Sliced Design, avec développement piloté par les comportements (BDD) puis TDD. À utiliser pour toute nouvelle fonctionnalité, page, entité ou use case dans app/.
---

# Développer une feature (BDD → TDD → FSD)

Avant toute chose : lire `docs/engineering/architecture.md` et `docs/engineering/testing.md`.

## Étapes (dans cet ordre)

1. **Cadrer** : une phrase de valeur utilisateur ; identifier la couche FSD (`entities`, `features`, `widgets`, `pages`) et le slice. Une règle métier → `domain` d'abord.
2. **Scénario BDD** (skill `dev-bdd`) : écrire `.feature` en français ou anglais cohérent avec le dépôt ; générer les steps ; **constater l'échec** (rouge) et le dire.
3. **TDD unitaire** (skill `dev-tdd`) : domaine (entités, use cases) → bloc/cubit (`bloc_test`) → repository/data. Un test à la fois ; implémentation minimale.
4. **Brancher** : DI (`@injectable`), route `go_router`, textes dans les ARB `fr` et `en`.
5. **Régénérer** : `dart run build_runner build --delete-conflicting-outputs` si freezed/injectable/l10n ont changé.
6. **Garde-fous** : `scripts/check.sh --fast` pendant le travail, `scripts/check.sh --full` avant de conclure.
7. **Revue indépendante** : agents `architecte-fsd` puis `testeur-bdd` (contextes séparés). Corriger les remarques bloquantes.
8. Mettre à jour la documentation (`docs/engineering/`) si une règle ou un chemin change.

## Règles de dépendance (rappel)

`app > pages > widgets > features > entities > shared` ; jamais d'import latéral entre slices ; `domain` sans Flutter ; la présentation dépend du domaine, jamais l'inverse.

## Sortie

Liste des fichiers créés/modifiés par couche, scénarios ajoutés, résultat réel de `check.sh --full`.
