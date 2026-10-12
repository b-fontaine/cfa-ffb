# Tests : BDD d'abord, TDD ensuite

Toute modification de comportement suit le cycle ci-dessous. Aucune étape ne se saute ;
aucun `skip`, `.only` ni test factice n'est toléré.

## Deux niveaux

| Niveau | Outil | Emplacement | Ce qu'il prouve |
|---|---|---|---|
| Comportement (BDD) | `bdd_widget_test` (Gherkin) | `app/test/bdd/*.feature` + `app/test/step/*.dart` | Ce que l'utilisateur voit et fait, application complète (routeur, DI, l10n) |
| Unitaire (TDD) | `flutter_test`, `bloc_test`, `mocktail` | `app/test/unit/<miroir de lib/>` | Règles métier, Bloc, repositories |
| Architecture | `flutter_test` | `app/test/tool/` | Le vérificateur d'architecture détecte chaque violation |
| Garde-fous | `flutter_test` | `app/test/tool/` | Chaque script (`validate_seances`, `check_coverage`, `check_l10n`, `check_widgetbook`, `check.sh --fast`) rejette ce qu'il doit rejeter, aux bornes (89/90/91, 119/120/121, 89,9/90/90,1 %) |

## Cycle de développement

1. **Feature** : décrire le scénario en Gherkin dans `app/test/bdd/<sujet>.feature`
   (mots-clés `Feature/Scenario/Given/When/Then/And`, texte en anglais, paramètres
   Dart entre accolades : `{'Add session'}`).
2. **Steps** : `cd app && dart run build_runner build` génère `test/bdd/<sujet>_test.dart`
   (ne jamais l'éditer) et les steps manquants dans `test/step/`. Implémenter les steps
   nouveaux ; réutiliser les existants (`I see {..} text`, `I tap {..} text`,
   `I enter {..} into {..} input field`, `the app is running`, `the device language is {..}`).
3. **Rouge** : `flutter test test/bdd` échoue pour la bonne raison (comportement absent).
4. **TDD interne** : descendre vers les unités nécessaires et, pour chacune,
   *test unitaire rouge → code minimal vert → refactor* (cas d'usage, Bloc, repository).
5. **Vert** : le scénario BDD passe ; `scripts/check.sh --full` est vert.
6. **Refactor** : nettoyer sans changer le comportement ; relancer les tests.

## Scénarios BDD du domaine (sans interface)

Les `.feature` du suivi des élèves (`record_results`, `progress_curve`,
`audience_change`, `suggested_session`) pilotent les cas d'usage réels via get_it
et les dépôts en mémoire, sans widget. Les steps partagent un monde
(`test/support/tracking_world.dart`) réinitialisé par le `Background`
`le club suit la saison {...}`.

- **Mots-clés Gherkin en anglais** : `bdd_widget_test` ne reconnaît que
  `Feature/Scenario/Given/When/Then/And/But` (vérifié dans le code du paquet et par
  un essai : `Fonctionnalité:`/`Soit` font échouer le générateur). Les libellés des
  scénarios et des steps sont en français.
- Le chargement d'un asset est de l'E/S réelle : dans `testWidgets` il passe par
  `tester.runAsync` (sinon le test se bloque).
- Le graphe get_it des scénarios est composé avec
  `configureDependencies(environment: Environment.test)` (dépôts en mémoire).
- Les tests unitaires du domaine utilisent `test/support/domain_world.dart` (dépôts
  en mémoire + catalogue de test, aucun mock) et `test/support/fixtures.dart`.

## Scénarios BDD de l'interface

Les parcours de l'interface (`students`, `student_sheet`, `progress_curve`,
`record_session`, `suggested_session_screen`, `maturity_assessment`,
`backup_screen`, `navigation`, `localization`, `design_system`) pilotent
l'application complète (`App`, routeur, get_it en environnement `test`) via
`test/support/ui_world.dart`, qui amorce le club par les vrais cas d'usage et fige
l'horloge au 12/10/2026. Les scénarios d'interface couvrent aussi :

- les liens profonds (`I go to the address of the sheet of {..}`) ;
- la courbe avec son alternative textuelle (`I see the curve of {..} with {n}
  attempts`) ;
- le thème clair/sombre et la langue de l'appareil (fr / en) ;
- le navigateur sans persistance durable (`StorageStatus` volatile) ;
- l'import refusé (version inconnue, passage invalide) sans écriture partielle.

Les Bloc de la présentation ont chacun un `blocTest` dans
`test/unit/features/<feature>/presentation/`. Les composants de `shared/ui` ont un
test de widget (`test/unit/shared/ui/`) vérifiant cibles >= 48 dp et sémantique.
Le mapping `InvariantCode` → message est testé avec des attentes littérales fr
et en (`test/unit/shared/ui/failure_message_test.dart`). Chaque composant ou
page publique a aussi un use case Widgetbook
(`widgetbook/lib/use_cases/`), exigé par `scripts/check_widgetbook.dart`.

## Tests de contrat des repositories

`app/test/contract/` contient **une seule** suite (`repository_contract.dart`,
`backup_contract.dart`) exécutée contre chaque implémentation : en mémoire
(`in_memory_contract_test.dart`) et drift sur `NativeDatabase.memory()`
(`drift_contract_test.dart`). Toute nouvelle implémentation de port s'ajoute en
fournissant un `RepositoryHarness` ; aucune règle de repository ne se teste en
double. Les spécificités drift (horodatages, suppression logique physique,
rollback, migrations, ouverture fichier) sont dans `test/unit/shared/persistence/`.

## Conventions

- Fichier de test = `<fichier_lib>_test.dart` dans le miroir de `lib/`
  (ex. `lib/features/plan_session/domain/plan_session.dart` →
  `test/unit/features/plan_session/plan_session_test.dart`).
- Noms de tests en anglais, formulés comme un comportement : `'rejects a blank title
  without storing anything'`.
- Un test = une raison d'échouer ; pas de logique conditionnelle dans les tests.
- Doubles : `mocktail` (`class _MockX extends Mock implements X;`) uniquement aux
  frontières (ports de repository, cas d'usage injectés au Bloc). Le domaine pur
  se teste sans mock quand c'est possible.
- Blocs : `blocTest` avec `build`, `act`, `expect` ; états comparés via `freezed`.
- Steps BDD : une fonction par phrase dans `test/step/<phrase_snake_case>.dart` ;
  `the app is running` réinitialise get_it avant chaque scénario.
- Les `.feature` sont la spécification vivante : tout nouveau comportement visible
  par l'utilisateur y apparaît, y compris pour les deux langues quand c'est pertinent.

## Couverture et mutation

- Seuil de couverture de lignes : **≥ 90 %** sur `lib/` hors code généré, `main.dart`
  et `app/di/injection.dart` (script `scripts/check_coverage.dart`). Tout fichier de
  `lib/` non chargé par un test fait échouer le contrôle.
- Mutation testing : `mutation_test` (`app/mutation-test.xml`), seuil de détection
  **≥ 85 %** ; un mutant survivant signale un test trop faible : renforcer l'assertion,
  pas le seuil.

## Commandes

```bash
cd app
dart run build_runner build        # (re)génère code + tests BDD
flutter test test/bdd              # comportement
flutter test test/unit             # unitaires
flutter test --coverage            # tout + lcov
```
