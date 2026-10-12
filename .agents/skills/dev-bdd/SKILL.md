---
name: dev-bdd
description: Écrire un scénario de comportement Gherkin (.feature) et ses steps avec bdd_widget_test pour l'application Flutter. À utiliser avant d'implémenter un comportement visible par l'utilisateur, ou pour ajouter une couverture comportementale.
---

# Test de comportement avec bdd_widget_test

Référence : `docs/engineering/testing.md` (conventions réelles du dépôt).

## Procédure

1. Placer le `.feature` dans le dossier de tests du slice concerné, nommé d'après le comportement.
2. Écrire en Gherkin : `Feature` (valeur), `Scenario` (un comportement), `Given/When/Then` en langage métier (animateur, séance, public) — pas de détails d'implémentation (widgets, bloc).
3. Générer les steps : `dart run build_runner build --delete-conflicting-outputs`, puis implémenter les steps générés avec des helpers réutilisables.
4. Lancer le test et **constater l'échec pour la bonne raison** (comportement absent, pas erreur de syntaxe).
5. Implémenter par cycles TDD (`dev-tdd`) jusqu'au vert.
6. Vérifier qu'un scénario couvre : cas nominal, cas limite métier (ex. durée enfants 90 vs adultes 120), état d'erreur.

## Bonnes pratiques

- Un scénario = un comportement ; pas de scénario fourre-tout.
- Données de test explicites dans le scénario (tableaux Gherkin) plutôt que cachées dans les steps.
- Les textes attendus passent par l'i18n : tester dans la langue par défaut et ajouter un scénario pour `en` si le comportement dépend de la locale.
- Interdits : `skip`, `solo`, `@ignore`, assertions vides, mock du système sous test.
