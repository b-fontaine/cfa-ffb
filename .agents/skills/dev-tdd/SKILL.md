---
name: dev-tdd
description: Appliquer le cycle TDD rouge → vert → refactor sur les tests unitaires Dart/Flutter (domaine, bloc, repository). À utiliser pour toute logique de production ajoutée ou corrigée, y compris les corrections de bugs.
---

# Cycle TDD

Un cycle = un comportement minuscule. Ne jamais écrire plus de code de production que ce qu'un test échouant exige.

## Boucle

1. **Rouge** : écrire UN test (nom = comportement attendu) ; l'exécuter ; vérifier qu'il échoue pour la bonne raison. Valeurs attendues calculées indépendamment de l'implémentation.
2. **Vert** : écrire le code minimal pour le faire passer ; exécuter toute la suite concernée.
3. **Refactor** : nettoyer en gardant le vert ; `scripts/check.sh --fast`.
4. Recommencer.

## Outils

- Domaine : tests Dart purs (`package:test` ou `flutter_test`), sans Flutter.
- Bloc/Cubit : `bloc_test` (`blocTest`), états `freezed` comparés par valeur.
- Dépendances externes : `mocktail`, uniquement aux frontières (repository, horloge, réseau) ; jamais le système sous test.
- Bug : écrire d'abord un test qui le reproduit, puis corriger.

## Qualité des tests (contrôlée par mutation testing)

- Une assertion par comportement ; vérifier les valeurs, pas seulement l'absence d'exception.
- Cas limites : listes vides, bornes (89/90/91 min), valeurs `null`.
- Un test qui ne casse pas quand on mute le code est un mauvais test : le renforcer plutôt que d'abaisser le seuil.
