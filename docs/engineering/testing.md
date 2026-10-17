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
- Les tests de widget des écrans du suivi partent d'un **modèle réel** :
  `test/support/sheet_world.dart` (`SheetWorld`) construit la fiche, la vue
  élève et la grille d'un groupe par les vrais cas d'usage sur le catalogue de
  test (3 blocs de 3 exercices), puis le widget est posé avec `pumpUi`.
  `narrow_layout_test.dart` pose les écrans du lot U9 sur 320 dp avec un texte
  à 100 % et 200 % (aucun débordement).

## Scénarios BDD de l'interface

Les parcours de l'interface (`students`, `student_sheet`, `progress_curve`,
`record_session`, `record_history`, `suggested_session_screen`,
`maturity_assessment`, `backup_screen`, `navigation`, `localization`,
`design_system`) pilotent
l'application complète (`App`, routeur, get_it en environnement `test`) via
`test/support/ui_world.dart`, qui amorce le club par les vrais cas d'usage et fige
l'horloge au 12/10/2026. Les scénarios d'interface couvrent aussi :

- les liens profonds (`I go to the address of the sheet of {..}`, `…of the showcase of {..}`,
  `…of the grid of the group {..}`) ;
- le parcours et la carte de chaleur (lot U9) : les cases, lignes et cellules
  se retrouvent par la **clé** que leur donne l'interface
  (`test/support/key_finders.dart` : `path-cell-<bloc>-<n>`, `path-row-<bloc>`,
  `showcase-cell-<i>-<n>`, `heat-cell-<bloc>-<élève>`, `heat-column-<élève>`,
  `group-alert-<i>`) et leur état se lit dans leur **nom accessible**
  (`the cell {..} is {..}`, `I see the grid described as {..}`), jamais dans la
  couleur ; les menus ⋮ se trouvent par leur infobulle
  (`I open the placement menu of {..}`) ;
- le catalogue en mode « Préparer » (lot U8, `session_catalogue.feature`) : les
  lignes se retrouvent par clé (`sheet:<id>`, `sheet-title:<id>`,
  `sheet-subtitle:<id>`, `review-badge:<id>`, `review:<id>:<motif>` (badge neutre d'une proposition mineure), `mark:<id>`,
  `catalogue-group:<id|none>`) et se lisent dans leur texte et leur sémantique
  (`the session {..} has the title {..} and the subtitle {..}`, `the session {..} shows the minor badge {..}`, `the session {..} shows the review reason {..}`, `the review badge
  of {..} explains {..}`, `the marker of {..} is announced as {..}`) ; la mise en
  page à deux colonnes se mesure sur la **géométrie** (`the exercise {..} is laid
  out in {n} columns`, fenêtre 719 puis 720 dp) ; le menu ⋮ et la copie se
  vérifient avec un presse-papiers simulé sur le canal de plateforme (`the
  clipboard is available` puis `the clipboard holds {..}`) ; l'origine du retour
  se lit sur le bouton (`the back button says {..}`) ;
- la séance guidée en mode « Mener » (lot U4, `session_guide.feature`,
  `session_guide_mode.feature`) : l'en-tête compact se lit par la position
  (`I see the guide at step {n} of {m}` lit « n/m » dans le `StepAppBar`) ; le
  public et la durée sont dans la feuille « La séance » (`I see the session
  audience {..}`) ; « Outline », « End session » et le mode passent par le menu
  ⋮ (`I open the guide menu`, `I open the guide outline`, `I end the guided
  session`, `I switch the guide to {..} mode`, la confirmation reste un
  `I tap {'Confirm'} text`) ; la mise en page se mesure sur la **géométrie**,
  clés `guide-header`, `guide-bottom-bar` et `step-media` (`the diagram is fully
  visible without scrolling`, `the guide header takes at most a quarter of the
  screen`, `the bottom bar offers {..}` qui vérifie aussi les cibles ≥ 48 dp,
  `the bottom bar stays on the screen`) à 390 × 844, 1280 × 800 et 320 dp avec
  texte à 200 % (`the text size is {200} percent`) ; le minuteur se pilote avec
  l'horloge de test (`the guide timer has run {n} seconds` le lance, laisse
  passer les secondes puis le met en pause) ; la provenance se lit par type de
  badge (`the provenance badges are {..}`) et l'annonce sémantique reste testée
  (`the proposal is announced to screen readers`) ; une section repliable se lit
  par son contenu construit ou non (`the section {..} is {..}`) ; l'origine se lit
  dans l'adresse (`the address is`, `the address contains`, `the address does not
  contain`) et le retour avec `I tap the back button` (flèche de l'en-tête du
  guide ou bouton texte des autres pages). Piège : la pause du minuteur demandée par
  la sortie de l'écran se termine dans la zone réelle (`Stream.periodic`) : l'étape
  `the guided session of {..} has its timer {..}` laisse d'abord finir un
  `runAsync` ;
- la courbe avec son alternative textuelle (`I see the curve of {..} with {n}
  attempts`) ;
- le thème clair/sombre et la langue de l'appareil (fr / en) ;
- le navigateur sans persistance durable (`StorageStatus` volatile) ;
- l'import refusé (version inconnue, passage invalide) sans écriture partielle.

Le schéma animé de la fiche d'un exercice (`exercise_sheet_diagram.feature`)
est piloté par l'application complète : le schéma, la quantité de bille et le
chevalet (une seule fois, par la carte de la fiche) en fr et en, lecture / pause, vitesses, deux schémas pour le rejet
naturel, exercice sans schéma, schémas illisibles (le dépôt de schémas est
remplacé à la frontière par `the diagram library is empty` / `cannot be read`).
Le comportement interne du lecteur (positions à des instants donnés, mouvement
réduit, échelle de texte) reste figé par `exercise_diagram.feature`, les tests de
widget et de peinture (le thème sombre et le texte à 200 % relèvent de ces
tests unitaires, pas de scénarios BDD ; les bornes exactes de durée de la
timeline aussi, `exercise_diagram.feature` n'en bornant qu'une à ×1) ; les tailles (portrait, paysage, texte à 200 %) par
`exercise_diagram_view_test.dart`.

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

Le lot 11 y ajoute `season_archive_contract.dart` (port `SeasonArchiveRepository` :
remplacement par saison, tri, suppression, archive vide sans ligne), les cas
`clôture des saisons` de `repository_contract.dart` et, dans
`backup_contract.dart`, le groupe `clôture de saison (format 4)` (aller-retour,
remplacement de l'archive, **un fichier antérieur à la clôture rétablit les élèves
effacés, rouvre la saison et supprime son archive**). La **parité d'effacement**
(`test/unit/shared/erasure_parity_test.dart`) garantit qu'à données égales
`EraseStudent` et `CloseSeason` (deux features qui ne s'importent pas) laissent
le même état dans chaque dépôt nominatif ; `physical_erasure_test.dart` vérifie en
plus, sur SQLite, qu'**aucune colonne d'aucune table** ne contient plus
l'identifiant ni le prénom d'un élève effacé par une clôture, archive comprise.

Les diagrammes ont leurs propres contrats sur les **vrais** fichiers
(`test/contract/`) : `diagrammes_format_test.dart` (chaque transcription passe
le validateur, le parseur et le mapper de production sans perte, et la timeline
se construit) et `catalogue_diagrammes_test.dart` (chaque exercice du catalogue
d'entraînement reçoit son schéma par `sheet` + `exercise` ; la liste de ceux qui
n'en ont pas est explicite).

Le plein écran (U3) a un double, `test/support/fake_fullscreen_controller.dart`
(`supported`, compteurs `enterCalls` / `exitCalls`, `emit` pour une bascule venue
du navigateur) : `UiWorld` le branche dans get_it à la place du contrôleur de
plateforme (`the device supports full screen` / `does not support` avant
`the app is running`). Les implémentations de plateforme sont fines : le natif se
teste par un canal de plateforme simulé (`SystemChrome`), la logique du web par sa
couture `FullscreenDocument` ; les liaisons `dart:js_interop`
(`app/platform/fullscreen_controller_web.dart`, seules non chargeables dans la
machine virtuelle) se vérifient au parcours web (Playwright, manuel).
**Exception de couverture assumée** : ce fichier est « référencé » par
`fullscreen_controller_factory.dart`, donc absent du dénominateur de
`scripts/check_coverage.dart` et de son alerte « NON CHARGÉ » ; ses lignes
exécutables (`fullscreenEnabled ?? false`, `_absorb`, écouteur
`fullscreenchange`) ne sont couvertes par aucun test automatisé. Un test
`flutter test --platform chrome` (`@TestOn('browser')`) les couvrirait, mais
la CI n'a pas de passe navigateur ; à ajouter au lot 15 avec le test PWA.

Le **rendu PDF** (lot 14) a ses doubles et ses garde-fous : `FakePrintRenderer`
(mesure à chasse fixe `FixedTextMeasure`, « PDF » réduit à une ligne qui compte
les pages) pour les cas d'usage et le cubit ; `FakePdfFiles` (`UiWorld` le branche
à la place de la sortie de plateforme : `the platform can print`, `the save dialog
is cancelled`) ; `FakeExportSource`. Le vrai `PdfPrintRenderer` se teste avec la
vraie fonte Exo 2 (`pdf_print_renderer_test`, document **non compressé** pour lire
les opérateurs : y inversé, pages dans l'ordre, dashes, rotation, gras simulé,
police embarquée, aucune action `/URI`) ; `catalogue_export_test` imprime les **28
séances × 2 publics × 2 langues** avec la vraie fonte (aucun caractère absent
d'Exo 2, nombre de pages, valeurs préremplies dans la colonne de gauche). Les
scénarios BDD lisent la **même scène** que le PDF dans l'aperçu
(`test/support/pdf_preview.dart`) et le fichier enregistré dans le double.
Les liaisons `dart:js_interop` de l'impression web
(`app/platform/pdf_files_web.dart`) ne sont chargeables que dans le navigateur :
même exception de couverture que le plein écran (vérifiées au parcours web ;
l'ouverture de la boîte d'impression du navigateur ne se pilote pas).
Limite connue : le garde « aucun accès réseau » du scénario BDD
(`network_access_is_forbidden`, `HttpOverrides`) ne voit que les clients
`dart:io` ; une requête web par `package:http` ou `fetch` ne serait pas
détectée. L'absence de réseau repose donc surtout sur le rendu lui-même (le
test unitaire du rendu : aucun lien `/URI` dans le PDF) et sur la règle
d'architecture qui réserve `pdf` à `export_sheet/data`.

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

## Couverture

- Seuil de couverture de lignes : **≥ 90 %** sur `lib/` hors code généré, `main.dart`
  et `app/di/injection.dart` (script `scripts/check_coverage.dart`). Tout fichier de
  `lib/` non chargé par un test fait échouer le contrôle.
- La pertinence des assertions est contrôlée par la relecture de l'agent
  `testeur-bdd` et par les tests de contrat (le mutation testing a été retiré, voir
  [quality-gates.md](quality-gates.md)).

## Commandes

```bash
cd app
dart run build_runner build        # (re)génère code + tests BDD
flutter test test/bdd              # comportement
flutter test test/unit             # unitaires
flutter test --coverage            # tout + lcov
```
