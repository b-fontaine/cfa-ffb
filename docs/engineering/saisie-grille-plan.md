# Plan d'exécution : saisie rapide en grille (lot U5)

Statut : **livré le 2026-10-15**. Corrige F4 de la [roadmap](roadmap.md). Source :
[ux/plan-ux-proposition.md](ux/plan-ux-proposition.md) (lot U5, § 4) et
[ux/recommandations-design.md](ux/recommandations-design.md) R11. Pas d'ADR :
aucune décision structurante (le domaine n'a gagné que des lectures).

## Décisions prises

1. **Pastilles, une par essai** (Q1 à Q8) : `potted` = nombre de pastilles
   pleines ; `passSubmitted(studentId, potted, total)` est inchangé.
2. **Tentatives** : compteur conservé, relégué sous la ligne et déplié à la
   demande ; scénarios « attempts cannot go below » et « more attempts than the
   sheet » intacts.
3. **Nom de l'exercice** : il vit dans la séance du catalogue. `SheetOption`
   porte `exerciseTitles`, `SessionOverview.exerciseName(ref)` le lit ; hors
   séance, libellé « bloc · n° ».
4. **Cumul affiché** (`SessionOverview.passedCount(élève, exercice)`) : lu
   dans `SessionOverview.progress`, dérivé par `GetSessionOverview` avec
   `StudentProgress.derive` (passages + positionnements, taux du catalogue) ;
   aucune règle de comptage n'est dupliquée. Un exercice encore acquis au
   positionnement (ADR 0008) compte pour `passesRequired` : il n'affiche jamais
   « 0 sur 5 ». Dès qu'un passage daté du jour du positionnement ou après le
   reprend, le cumul revient à `ExerciseResult.passedCount`. Le cas d'usage
   dépend désormais d'`AcquisitionRepository`.
5. **`StudentChip`** (`shared/ui`) : prénom + état (à faire, manqué, réussi),
   utilisé dans les deux modes de `StudentPassRow` ; `SectionCard.header`
   permet de le placer à la place du titre texte.
6. **Feuille basse** : `showRecordSheet` (couche `app`) héberge l'ouverture puis
   la saisie ; les pages existantes sont réutilisées, câblées une seule fois
   par `buildRecordSetup` / `buildRecordSession` (`app/record_screens.dart`),
   aussi utilisés par les routes. Le guide n'est jamais démonté ; le retour
   système ferme la feuille. Les routes `/record/new` et `/record/:id` restent
   (liens profonds, ADR 0007). `AppRoutes.recordFromGuide` et le paramètre
   `step` de `onRecord` n'avaient plus d'appelant : supprimés avec leurs tests.
7. **Message de refus** : `AppAlert` niveau attention (ADR 0010), jamais du
   texte `colorScheme.error`. Sélecteur d'exercice : un seul nom accessible
   (le `DropdownMenu` porte son libellé, plus de `Semantics` englobant).
8. **Troisième passage** : le bouton disparaît à la limite et un badge dit
   « Maximum atteint » ; le message de refus du domaine est conservé.

## Étapes

| # | Étape | Couches |
|---|---|---|
| 1 | Grille : `StudentPassRow`, `passedCount`, `history` | domaine, présentation |
| 2 | Sélecteur nommé, liste compacte, historique groupé | domaine, présentation, l10n |
| 3 | Feuille basse depuis le guide, Widgetbook, docs | app, tests, docs |

## Scénarios BDD

`record_session.feature` : ligne par élève, 4 pastilles sur 6 puis Saisir,
passage manqué neutre, tentatives sous la ligne, sélecteur nommé non tronqué à
390 dp, dix élèves sur 844 dp, ligne compacte (clé `student-row-compact`, 48 dp,
pastilles sans score), plus de bouton Saisir au deuxième passage, exercice
acquis au positionnement affiché « 5 sur 5 ». `record_history.feature` :
historique groupé. `session_guide.feature` : feuille de saisie sur l'exercice
courant, guide à la même étape, retour système.

## Limites connues

- L'historique groupé place les passages d'un élève non résolu dans un
  groupe « Élève absent du groupe » ; les pastilles y sont en lecture seule.
- `exerciseName` ne connaît que les exercices d'entraînement de la séance.
- La feuille basse recrée les blocs de saisie ; fermer puis rouvrir relit la
  séance ouverte (aucune perte : tout est persisté à « Saisir »).
