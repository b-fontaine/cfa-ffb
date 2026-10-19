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
(`in_memory_contract_test.dart`), drift sur `NativeDatabase.memory()`
(`drift_contract_test.dart`) et, depuis FB4, **Firestore** sur un faux en mémoire
(`firestore_contract_test.dart`, écarts dits dans la section « Dépôts Firestore (FB4,
partie 3) »). Toute nouvelle implémentation de port s'ajoute en
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

## Règles Firestore et environnement Firebase (FB1)

- **Règles** : `scripts/rules_test/*.test.mjs` (`node:test` + `@firebase/rules-unit-testing`),
  lancés par `scripts/rules_test.sh` contre l'émulateur (`firebase emulators:exec`). Lot FB1 :
  refus par défaut, lecture **et** écriture, anonyme comme authentifié, toute collection ; chaque
  refus porte sur un document qui existe (le refus vient des règles, pas d'une absence) et un test
  de sensibilité prouve qu'une règle ouverte ferait échouer la suite. Les cas de la matrice rôle x
  action s'ajouteront dans ce dossier avec les règles (FB3). Non exécuté par `flutter test`.
- **Environnement** : `FirebaseEnvironment` (`app/lib/app/firebase_environment.dart`) décide de la
  cible Firebase. Sans `--dart-define=FIREBASE_EMULATOR=true` : jamais d'émulateur ; avec : debug et
  profile parlent aux émulateurs (`10.0.2.2` sur l'émulateur Android, `127.0.0.1` ailleurs,
  `FIREBASE_EMULATOR_HOST` pour un appareil physique) ; **release refuse** le drapeau
  (`FirebaseEnvironmentError`, au câblage, avant le premier écran). Tests : `firebase_environment_test`,
  ports comparés à `firebase.json`.
- **Initialisation** : `FirebaseStartup` (`firebase_startup_test`) reçoit une `FirebaseGateway` ; les tests
  utilisent `test/support/fake_firebase_gateway.dart`, **jamais le SDK ni le réseau**. L'implémentation
  réelle (`platform/firebase_sdk_gateway.dart`) n'est couverte que pour son aiguillage (les trois
  appels directs au SDK sont des tear-offs non exécutés en test). Pas de scénario BDD en FB1 : aucun
  comportement visible n'a changé (le premier, la connexion, arrive en FB2).
- **Application sous émulateurs** : `task emulators` puis `flutter run -d chrome --dart-define=FIREBASE_EMULATOR=true`.

### Mutations à la main des règles (relecture FB3, 2026-10-18)

Copie des règles (`RULES_FILE=copie.rules`, jamais le fichier versionné), suite `bounds.test.mjs` :

| Mutant | Résultat |
|---|---|
| `studentInGroup` remplacé par `studentExists` (enseignant, A1) | **tué** : « un enseignant ne crée de donnée que sur un élève de SON groupe » |
| code d'étiquette `x` ajouté à la liste autorisée | tué : étiquettes de séance (un code inconnu, même court) ; **a d'abord survécu** : test renforcé (les huit codes, `x`, un intrus parmi les codes connus) |
| `hasOnly` des passages neutralisé (`true \|\|`) | tué : champ inconnu refusé dans chaque collection, appartenance immuable |
| borne de taille totale de `idList` retirée | tué : 900 Ko dans un identifiant de member et de groupe |
| `strList30` remplacé par `idList` (`teacherUids: [1]`) | tué : un enseignant doit être un texte (A27) |
| `optString` élargi de 2 000 000 caractères | tué : champ connu de 900 Ko, commentaire à 501, archive |
| note de bilan 1 à 5 au lieu de 1 à 4 | tué : types et bornes des valeurs |
| (FB4) `audienceHistory.size() <= 10` passé à 11 | tué : `historique du public` (11 changements refusés) |
| (FB4) dernier contrôle `changeAt(…, 9)` retiré | tué : « chaque élément est contrôlé, même le dixième » |
| (FB4) public de l'historique non contrôlé (`true`) | tué : même test (`seniors` refusé, aux rangs 0, 4 et 9) |
| (FB4) lecture des appartenances ouverte à tout membre (`staffReadsGroup` remplacé par `isMember`) | tué (3 cas de `repositories.test.mjs` : par groupe, par élève, liste du club) |
| (FB4) l'enseignant liste toutes les fiches (`hasAny` remplacé par `isTeacher`) | tué : « l'enseignant interroge ses groupes, jamais ceux d'un autre » |

Mutants M2 et M5 de la première série, qui n'ajoutaient qu'une valeur permise sans rien retirer, ne prouvaient rien : remplacés ci-dessus.

## Dépôts Firestore (FB4, partie 1)

- **Suite de contrat** : `student_group_contract.dart` (extraite de `repository_contract.dart`, qui la rejoue sur drift et la mémoire) et `settings_contract.dart`
  tournent aussi sur les dépôts Firestore (`firestore_contract_test.dart`). Les autres ports n'ont pas encore de dépôt Firestore (partie 2).
- **Pourquoi `fake_cloud_firestore` et pas l'émulateur pour le contrat Dart** : un test sur la VM Dart ne charge pas le plugin natif `cloud_firestore`.
  Le chemin réel a été essayé : `flutter test --platform chrome` + émulateur Firestore à règles ouvertes (`firebase emulators:exec --config`). `-d chrome` ne
  trouve aucun test ; avec `--platform chrome` il faut `TestWidgetsFlutterBinding.ensureInitialized()`, puis `Firebase.initializeApp` ne répond pas (arrêt
  à 30 s : le SDK JavaScript se charge depuis `gstatic.com` dans la page du test). Non retenu faute de stabilité ; aucun test n'est ignoré.
- **Ce que le contrat sur faux prouve** : les dépôts tiennent le même comportement que drift et la mémoire, avec la vraie traduction des valeurs
  (`FirestoreDocumentStore` : dates, listes, date du serveur) et des requêtes (`FirestoreSdkAccess`). **Ce qu'il ne prouve PAS** : les règles de sécurité (le faux n'en
  applique aucune), les index (idem, et l'émulateur non plus), les chemins réels côté serveur, les quotas, le hors ligne, le `permission-denied` réel, l'ordre
  serveur des résultats. Un `StoreFailure` n'y est joué que par `InMemoryDocumentStore.failing`.
- **Pendant contre l'émulateur** : `scripts/rules_test/repositories.test.mjs` (dans `rules_test.sh`, donc `check.sh --full`) joue les **mêmes opérations** que les
  dépôts (mêmes chemins, mêmes champs, mêmes requêtes : égalité sur `groupId` et `studentId`, `array-contains-any` sur `groupIds`) avec les **vraies règles**, par rôle :
  accepté pour le directeur, refusé pour l'enseignant d'un autre groupe, le parent, un autre club. Les formes de documents y sont copiées des tests Dart (« writes exactly the fields
  firestore.rules allows ») : si un champ change d'un côté, l'autre échoue. Ce que ce test ne prouve pas non plus : que **le code Dart** envoie ces formes (c'est le test
  Dart qui le fige) ; la jonction n'est donc faite que par ces deux jeux de littéraux identiques.
- **Écarts de comportement assumés, testés** : l'ordre de `all()` (élèves par inscription puis identifiant ; groupes par identifiant ; appartenances par groupe, élève, début) ;
  `delete` = suppression physique (le contrat n'exige que « invisible » et « réapparaît si on sauve à nouveau ») ; `byId` d'un groupe invisible pour un enseignant est un refus, pas `null`.
- **Unitaires** : `club_store_test` (chemins, club résolu à chaque appel, sans club = `denied`, lots de 500), `firestore_*_repository_test` (champs écrits, `groupIds`
  tenus par les groupes, `teacherUids` conservé, requêtes par rôle, documents mal formés, isolation entre clubs), `document_values_test`, `data_backend_test`
  (défaut drift, valeur inconnue = erreur), `data_backend_module_test` (pour `firestore` puis `drift`, **les 11 dépôts de données** et `UnitOfWork` : `firestore` rend les dépôts Firestore et un `CompositeUnitOfWork` (drift dehors, `FirestoreUnitOfWork` dedans), `drift` rend les instances drift ; mutation : câbler `drift` à la place de `FirestoreAcquisitionRepository`, ou `drift` comme lot intérieur du composite, fait échouer le test du dépôt et celui de l'unité de travail), `production_graph_test` (la production câble drift sans réglage). Concurrence : `groupIds` par `ArrayUnion`/`ArrayRemove` (stock qui écrit entre la lecture et le lot), fiche écrite par fusion même si la lecture ne la voit pas ; requêtes `array-contains-any` bornées à 30 valeurs (journal des requêtes du stock en mémoire, et l'émulateur refuse la 31e).
- **Erreurs d'ouverture de session** : `authentication.feature` (« Clubs refused by the server… », « A missing server index… » : écran « Access to your clubs refused », ni
  « Retry » ni « Service unreachable ») ; `auth_cubit_test` (état, aucun repli sur le club retenu, une seule ligne de journal sans e-mail ni uid, reprise après
  `refresh`, déconnexion) ; `store_memberships_source_test` (`permission-denied` et `failed-precondition` = refus, `unavailable` et `other` = injoignable). Mutation : traduire
  `failedPrecondition` en `MembershipsUnavailable` fait échouer le BDD « missing server index ».
- **Index** : voir [quality-gates.md](quality-gates.md) (`check_indexes_test`, mutation incluse).

## Dépôts Firestore (FB4, partie 2)

- **Unité de travail** : `unit_of_work_contract.dart`, rejoué sur le double en mémoire (`firestore_unit_of_work_test`) **et** sur `fake_cloud_firestore`
  (`firestore_contract_test`) : écritures appliquées ensemble, **lecture de ses propres écritures** (une fiche créée dans l'unité est vue par l'enregistrement du groupe),
  rien d'écrit si le corps échoue, unité imbriquée jointe à l'englobante, 500 écritures acceptées, 501 refusées par une erreur explicite (`batchTooLarge`, avant toute écriture).
  Le test « une écriture refusée par le stock n'écrit rien » ne tourne que sur le double : **`fake_cloud_firestore` applique les écritures d'un lot une à une**
  (mesuré : la première reste), le contrat le déclare (`storeRollsBack: false`) au lieu de l'ignorer. L'atomicité du **vrai** lot est prouvée contre l'émulateur
  (`repositories.test.mjs`, « un lot dont une écriture est refusée n'écrit rien »). Unitaires : un seul lot envoyé, deux écritures d'un même document fusionnées (`ArrayUnion`
  cumulés), `composite_unit_of_work_test` (le lot Firestore part avant la validation de drift ; son échec annule drift).
- **Création d'un élève par un enseignant** : `firestore_enroll_by_teacher_test` joue le cas d'usage `EnrollStudent` avec les dépôts Firestore d'un enseignant : **un seul lot**,
  fiche (`groupIds: ['g1']`) et appartenance, **ni la saison ni le groupe réécrits** (l'enseignant n'y a pas droit). Mutation : réécrire le groupe inchangé fait échouer les deux tests.
  Contre les règles (`repositories.test.mjs`) : le lot est accepté pour l'enseignant du groupe, refusé pour une fiche existante, sans fiche dans le lot, pour le groupe d'un autre
  enseignant, pour les autres rôles ; mise à jour et suppression d'une appartenance par l'enseignant toujours refusées.
- **Contrat de la planification** : `planning_contract.dart` (saisons, séances planifiées, séances données) tourne sur la mémoire, **drift** et Firestore (faux) ;
  `season_archive_contract.dart` aussi sur Firestore. Les listes y sont attendues dans l'ordre chronologique (celui de la première sauvegarde pour drift et la mémoire).
- **Unitaires** : `firestore_planning_repositories_test` (champs écrits = liste blanche des règles ; séance sans groupe = garde défensive (`ServiceFailure`, la règle métier est dans `PlanSession`, `plan_session_test`) ; ouverture concurrente d'une saisie (`open`, `resume`, `createIfAbsent`, `createdAt` jamais envoyé à une mise à jour) ;
  une saison inchangée n'est pas réécrite ; `createdAt` conservé ; requêtes par rôle : un groupe à la fois pour l'enseignant et la famille, **aucune lecture** de saisie pour
  un parent ou un élève ; `eraseStudent` par `ArrayRemove` serveur ; archive sans identifiant d'élève ni de groupe), `rule_bounds_test` (bornes du domaine = bornes des
  règles, lues dans `firestore.rules`), `sitting_id_test` et `open_session_test` (identité déterministe d'une saisie liée, UUID pour une saisie libre).
- **Contre l'émulateur** : `scripts/rules_test/planning.test.mjs` (dans `rules_test.sh`) joue les **mêmes opérations** par rôle : écriture dans son groupe seulement, lecture
  par groupe (staff et famille pour les séances planifiées, **staff seul** pour les saisies), requêtes que le dépôt Dart évite (saisies par élève seul pour un enseignant :
  refusées), `array-contains-any` du gestionnaire, bornes (titre 120, 60 présents, étiquettes de la liste fermée), archives (compteurs seulement, écriture au gestionnaire).
  **Aucun index composite** : toutes les requêtes sont d'égalité ou `array-contains-any` sur un seul champ ; `firestore.indexes.json` est inchangé et
  `tool/check_indexes.dart` reste vert (pas de nouvel index, donc pas de mutation à prouver).

- **Limites de la preuve de l'ouverture concurrente** : (1) le faux Firestore **sérialise** les transactions (`isolatedTransactions: false` dans le contrat) : le test Dart « deux ouvertures simultanées convergent »
  ne prouve que la logique du dépôt, pas l'isolation du serveur ; (2) l'ouverture concurrente **côté Dart** n'est **pas rejouée contre l'émulateur avec le SDK Dart** : `planning.test.mjs` en joue une **réplique en JS**
  (`openSitting` : transaction « lire puis créer », puis `arrayUnion`), copiée des opérations du dépôt ; une divergence entre le dépôt Dart et cette réplique ne serait vue ni par l'un ni par l'autre
  (le dépôt Dart contre l'émulateur reste à faire avec le parcours navigateur de la partie 3). Le refus d'une union de plus de 60 présents est rejoué par un double qui imite la règle (`_BoundedSpy`), la règle
  elle-même l'étant dans `bounds.test.mjs` / `planning.test.mjs`.
- **Reprise et ouverture** : la reprise **remplace** les présents (contrat `resume changes the blocks and replaces the presents` sur drift, mémoire et Firestore ; `open_or_resume_session_test`), l'ouverture les **réunit**
  (contrat `open keeps the blocks and the tags, adds the presents`). **Import avec Firestore** : `backupImportUnsupportedContract` (`ServiceFailure` `unsupported`, rien d'écrit, côté Firestore comme côté drift).

### Mutations à la main (FB4, partie 2)

Copie des règles (`RULES_FILE=copie.rules`), `repositories.test.mjs` (A-C) ou `planning.test.mjs` (D-H) :

| Mutant | Résultat |
|---|---|
| (A) `!exists(fiche)` retiré de `teacherEnrolls` | **survivait** à la série d'origine (les autres conditions refusaient le cas testé) ; **tué** depuis par « ATTAQUE : une appartenance seule, pour une fiche DÉJÀ existante qui satisfait tout le reste… » (`repositories.test.mjs`), où `!exists` est la seule condition qui refuse (fiche existante, groupe et jour d'entrée conformes) : la condition n'est donc pas redondante, gardée |
| (B) `getAfter(fiche).groupIds` retiré de `teacherEnrolls` | tué : le même test et « un enseignant ne peut pas écrire le groupe ni ses appartenances » |
| (C) `teachesGroup` remplacé par `isTeacher` dans `teacherEnrolls` | **survit, équivalent** : la fiche neuve porte des groupes bornés à ceux de l'enseignant (`students.create`) et `getAfter` impose que le groupe de l'appartenance en fasse partie ; la condition est une défense en profondeur, gardée |
| (D) lecture des séances planifiées : `familyInGroup` remplacé par `isFamily` | tué : « la lecture suit le groupe » |
| (E) lecture des saisies ouverte à tout membre (`isMember`) | tué : « un parent et un élève ne lisent AUCUNE saisie », « un enseignant interroge ses groupes un à un » |
| (G) `idList(presentStudentIds, 60)` passé à 61 | tué : « 60 élèves présents au plus » |
| (H) archives écrites aussi par l'enseignant | tué : « un enseignant lit mais n'écrit pas » |
| (I) identifiant de l'appartenance d'un enseignant non vérifié (`membershipId == …` retiré de `teacherEnrolls`) | tué : « l'appartenance d'un enseignant est liée à son contenu » |
| (J) `from` non lié au début de l'historique de la fiche neuve (`audienceHistory[0].effectiveFrom == d.from` retiré) | tué : le même test (seconde période arbitraire) |
| (K) saison de l'appartenance non liée à celle du groupe (`get(groupe).seasonId == d.seasonId` retiré) | tué : le même test (saison libre) |
| (L) période fermée admise (`d.get('to', null) == null` retiré) | tué : le même test |
| (M) `createdAt` autorisé dans le diff d'une mise à jour de saisie | tué : « createdAt : exigé et daté du serveur à la création, jamais dans le diff d'une mise à jour » et « la date de création d'une saisie est figée » |
| (N) `createdAt` non exigé à la création d'une saisie | tué : le même test (« création sans date ») |
| (F) lecture d'une saisie **existante** ouverte à tout enseignant (`manages \|\| isTeacher` au lieu de `staffReadsGroup`) | tué : « get (groupe g1/g2) : animateurs du groupe » (matrice) et « un enseignant lit une saisie ABSENTE… » (`existante, autre groupe`) |
| (O) lecture d'une saisie absente refusée à l'enseignant (retour à `staffReadsGroup(resource.data.groupId)` seul) | tué : « un enseignant lit une saisie ABSENTE de son club » et « deux appareils ouvrent la même saisie en même temps » |
| (P) `mayProbeAbsent` : l'enseignant ne lit qu'un identifiant aléatoire (le test sur le groupe de l'identifiant retiré) | tué : « ATTAQUE… » (sessions et saisies), « deux appareils ouvrent la même saisie », « la reprise… REMPLACE les présents » |
| (Q) `mayProbeAbsent` : l'enseignant ne lit qu'un identifiant portant son groupe (la branche « identifiant aléatoire » retirée) | tué : « un enseignant lit une saisie/séance ABSENTE de son club » et les deux « ATTAQUE… » (un enseignant ne pourrait plus créer une saisie libre ni une séance planifiée, à identifiant UUID) |
| (R) `mayProbeAbsent` revenu à `manages \|\| isTeacher` (le comportement avant resserrage) | tué : « ATTAQUE : lire une séance/saisie ABSENTE à identifiant déterministe d'un autre groupe est refusé » (un enseignant de g2 apprenait si g1 avait tenu une séance) |

## Dépôts Firestore (FB4, partie 3)

- **Rang dérivé (décision 17)** : `exercise_attempt_test` / `exercise_result_test` (tri par date, ordre reçu à égalité, `lastAttemptRank`), `delete_attempt_test` (**aucune** écriture que la suppression, rangs recalculés, plus d'`UnitOfWork`), `record_attempt_test`, `correct_attempt_test`,
  `recall_selector_test` (le rang dérivé départage deux exercices du même jour). BDD : `record_history.feature` (deux scénarios : les passages d'une séance gardent l'ordre d'enregistrement ; la suppression du premier laisse le second « Passage 1 » dans les courbes) ;
  les scénarios existants n'ont **pas** été modifiés. Sauvegarde : l'aller-retour (`backup_contract`, drift et mémoire) écrit le rang dérivé et lit le fichier dans son ordre quel que soit le `passIndex` qu'il porte ; l'ancien test « même rang deux fois refusé » est retiré (la règle n'existe plus), « plus de passages que permis » le remplace.
  Migration : `migration_test` (v11 vers v12 : colonne retirée, passages et ordre conservés ; schéma v12 = instantané).
- **Contrat complet sur Firestore** : `repositoryContract` (tous les dépôts de données du `RepositoryHarness`) est joué sur le faux Firestore avec le **montage de production** (`DataBackendModule` : unité composite drift + Firestore, `runProgress` local) ; `acquisitionContract`,
  `acknowledgementContract`, `planningContract`, `seasonArchiveContract`, `settingsContract`, `studentGroupContract`, `unitOfWorkContract` aussi. **Écarts dits, jamais ignorés** (`ContractTraits`) : (1) les listes y sont en ordre canonique (jour puis identifiant ; passages : `createdAt` puis identifiant), pas en ordre de première sauvegarde ;
  (2) la saison, les groupes et les fiches doivent exister d'abord (groupe et saison dénormalisés) : les tests du groupe `passages`, `bilans` et `séances planifiées` les créent (`seedOwners`) pour toutes les implémentations ; (3) une séance planifiée sans groupe n'existe pas (les cas « sans groupe » ne sont pas enregistrés pour Firestore) ;
  (4) rejouer l'identifiant d'un passage le remplace sur drift et en mémoire, pas sur Firestore (ajout seul : `correct`). Un test d'**ordre à date serveur égale** et de **deux appareils** (deux dépôts sur les mêmes documents) est dans `firestore_progress_repositories_test`.
- **Ce que le faux ne prouve pas** : les règles de sécurité, les index, les chemins réels, les quotas, le hors ligne, l'isolation des transactions ; l'**application immédiate** d'un lot au cache : `fake_cloud_firestore` l'applique en quelques tours de la file d'événements, le SDK dès l'appel. Le harnais (`_SettlingUnitOfWork`) laisse donc la file se vider
  après l'unité composite, qui n'attend plus le serveur ; sans lui, une lecture immédiate pourrait manquer le lot. Un **refus tardif du serveur** (règles, quota) n'est pas joué : le faux n'en émet pas ; `SendTracker` est testé à part (`send_tracker_test`).
- **Hors contrat Firestore, et pourquoi** : la **sauvegarde** (`backupContract` : export complet, import) : l'import d'une sauvegarde **avec** saisie est `unsupported` (une saisie se crée par transaction, impossible dans un lot) jusqu'à **FB7** (lots reprenables, `backupImportUnsupportedContract` rejoué avec le montage de production) ;
  **sans** aucune saisie il est supporté et atomique, mais refuse une séance planifiée sans groupe (`backupImportWithoutSittingContract`, figé) ; `StudentEraser` côté serveur : **FB8** (`eraseStudent` des dépôts est testé, mais l'enchaînement de l'effacement, le marqueur `erasing` et les lots reprenables ne sont pas écrits).
- **Unité de travail hors ligne** : `offline_unit_of_work_test` (un store dont le commit **ne se termine jamais**, comme le serveur hors ligne : l'unité composite se termine, la transaction drift se ferme, une écriture locale suivante n'est pas bloquée, l'envoi reste « en attente » sur `SendStatus`, 501 écritures refusées avant l'envoi). **Rouge vu** : avec l'ancienne attente de l'accusé, les deux premiers tests expirent (`TimeoutException`). `send_tracker_test`.
- **`RulesStore` par club** : `auth_rules_reload_test` (réglages du club à l'activation, à la bascule, retour aux valeurs par défaut sans document, refus de lecture sans blocage de l'ouverture, déconnexion, préférences d'appareil intactes). **Rouge vu** : sans l'appel de `ReloadRules`, les tests d'activation, de bascule et de déconnexion échouent. Les règles qui ne sont pas des réglages du club (`RulesStore.base`) survivent à la bascule (test dédié) ; les étapes BDD « the passes required are set to » (enregistre le réglage, comme l'application) et « the persistent alert threshold is » (règle de base) en tiennent compte.
- **Unitaires** : `firestore_progress_repositories_test` (champs écrits = liste blanche des règles ; aucun `passIndex` ; `add` sans lecture et par `set` simple ; correction = billes seulement ; ordre `createdAt` puis identifiant, passage sans date serveur dernier ; **requêtes par rôle** enregistrées : un enseignant prouve toujours `groupId`, la famille `studentId`, un parent n'envoie aucune requête de bilan ;
  propriétaire d'un bloc acquis (saison ouverte, puis identifiant ; groupes de l'enseignant ; fiche sans groupe refusée) ; acquittement : `createdBy` = uid, conservé au remplacement, groupe du dernier passage acquitté). Mutation : tri par date serveur neutralisé, fait échouer l'ordre. `identifier_shape_test` (forme des identifiants).
  `firestore_document_store_test` et `firestore_sdk_access_test` (`AllEqual`, `readQueryAll`).
- **Contre l'émulateur** : `scripts/rules_test/progress.test.mjs` joue les **mêmes opérations** par rôle (copiées des tests Dart) : création d'un passage (enseignant du groupe, élève du groupe, directeur ; `createdAt` serveur exigé, ni absent ni antidaté ; plus de `passIndex`), ajout seul (rejouer un identifiant refusé), correction limitée à `potted` et `total`,
  requêtes autorisées et **refusées** par rôle (un enseignant sur l'élève seul ou la séance seule ; la famille par groupe ; une autre fiche), deux passages écrits dans le même lot au même instant (même `createdAt`, l'identifiant seul les ordonne), suppression sans réécriture des autres, blocs acquis (lus par la famille de la fiche liée), bilans et acquittements (jamais lus par la famille),
  `createdBy` = uid. `matrix.test.mjs` et `bounds.test.mjs` mis à jour (`createdAt` d'un passage, `createdBy` d'un acquittement). **Aucun index composite** : égalités seulement ; `firestore.indexes.json` inchangé et `tool/check_indexes.dart` vert.
- **Routeur** : `planner_route.feature` (trois scénarios, un par page d'origine : le groupe arrive dans l'adresse `/planner?group=…`). **Mutation vue** : retirer le groupe des trois appels du routeur fait échouer les trois scénarios.

### Mutations à la main (FB4, partie 3)

Copie des règles (`RULES_FILE=copie.rules`), `progress.test.mjs`. Les trois mutants ont été posés **ensemble** (quatre tests tués) ; l'attribution se lit dans le contenu des tests.

| Mutant | Résultat |
|---|---|
| (S) `createdAt == request.time` retiré de la création d'un passage | tué : « `createdAt` est la date du SERVEUR, exigée : ni absente, ni antidatée » |
| (T) mise à jour d'un passage sans `affectedKeys().hasOnly(['potted', 'total', 'updatedAt'])` | tué : « la correction en place ne change que `potted` et `total` » et « ajout seul : rejouer un identifiant existant… » |
| (U) `createdBy == request.auth.uid` retiré de la création d'un acquittement | tué : « création : `createdBy` est l'uid du compte, pas celui d'un collègue » |

## Authentification (lot FB2)

- **BDD** : `authentication.feature`. Les BDD existants s'exécutent **connectés** : `UiWorld.prepare` crée le compte de
  l'animateur (`animateur@example.org`, adresse vérifiée, session persistée, un seul club « Test club », rôle `director`) dans
  l'`InMemoryAuthRepository` ; un `Given` peut déconnecter (`nobody is signed in on the device`), créer un compte
  (`the account … exists with the password …`, `… but is not verified`), ajouter des clubs (`… is a {'teacher'} of the club …`),
  retenir un club (`the club … is remembered for … on the device`), couper les clubs (`the clubs of the account cannot be read`)
  ou le service (`the account service is unavailable`). `I relaunch the app` / `I reload the page` / `the app restarts`
  réinitialisent l'`AuthCubit` : un lancement relit la session persistée (l'annulation d'un abonnement n'est pas attendue,
  elle ne se termine pas dans la zone simulée).
- **Unitaires** : `test/support/auth_rig.dart` assemble un `AuthCubit` avec ses doubles en mémoire (`AuthRig`). Le dépôt
  Firebase se teste sur un `AuthSdk` scripté (tous les codes d'erreur) ; `FirebaseAuthSdk` sur un `FirebaseAuth` mocktail ;
  `SharedPreferencesKeyValueStore` sur `InMemorySharedPreferencesAsync` (`shared_preferences_platform_interface`, dépendance de test).
- **Ce que prouvent les BDD d'échec de connexion** : le message affiché pour `invalidCredentials`. Ils tournent sur
  `InMemoryAuthRepository`, qui lève déjà `invalidCredentials` pour un mauvais mot de passe comme pour une adresse inconnue :
  ils ne prouveraient rien si l'anti-énumération de `FirebaseAuthRepository` était cassée. Cette garde est la **suite de
  contrat** `test/unit/entities/account/auth_repository_contract_test.dart` (mêmes assertions sur les deux implémentations,
  plusieurs variantes de codes du service) et le test unitaire du dépôt Firebase. Le `detail` d'un `AuthFailure`
  (`wrong-password`, `user-not-found`) diffère et n'est jamais affiché ; le `code`, qui pilote le message, est identique.
- **Bornes** : la longueur minimale du mot de passe est fixée par des littéraux (9 refusé, 10 et 11 acceptés) dans
  `use_cases_test.dart` et par un scénario BDD à 10 caractères, pas seulement par la constante.
- **Changement de club** : `ClubScoped` (reconstruction de toute l'interface) est testé à part (`club_scoped_test.dart`) :
  l'état local d'un écran est remis à zéro quand le club change, conservé quand il reste le même.
- **Fumée du build web compilé** : `scripts/web_smoke.sh` (dans `check.sh --full` et la CI ; prérequis Node, Java, `npm ci`
  et Google Chrome, échec explicite sinon). Il charge `app/build/web` (build **release** de `scripts/build_web.sh`) dans Chrome
  piloté par `playwright-core`, renvoie les appels du SDK vers l'émulateur Auth et **refuse tout autre hôte** que localhost (`gstatic.com` compris, FB5a :
  le SDK web est servi par l'application, le test exige les trois fichiers de `firebasejs/`) : démarrage jusqu'à l'écran de connexion, mauvais mot de passe et adresse inconnue (même message), connexion
  d'un compte vérifié **jusqu'à l'accueil du club retenu sur l'appareil** (assertion de succès ; le club retenu est posé dans `localStorage`
  parce que Firestore est refusé), session conservée au rechargement, déconnexion ; « Service injoignable » (sans club retenu) est un test
  distinct du chemin d'échec, jamais le chemin nominal. Il a été écrit après un blocage sur l'écran de démarrage qu'aucun autre test ne pouvait voir.
- **Application + émulateurs Auth et Firestore + graine** : `scripts/emulator_e2e.sh` (dans `check.sh --full` et la CI ; mêmes prérequis plus Flutter).
  `firebase emulators:exec` (projet `demo-cfa-ffb`), graine, `flutter run -d web-server --dart-define=FIREBASE_EMULATOR=true` (**mode debug** : release
  refuse l'émulateur, profile est inutilisable, voir le piège ci-dessous), puis `scripts/emulator_e2e/e2e.test.mjs` dans Chrome : la directrice se
  connecte, « Mon club » affiche les quatre autres membres (lus dans Firestore sous les règles) ; un parent atterrit sur « Mes enfants », sans « Mon club »
  ni onglet d'animateur (sa liste d'enfants vient encore du stock local : FB4). Ce parcours **échoue** si l'application vise un autre projet que celui des
  émulateurs (constat de relecture : projet réel `animation-billard` face à une graine `demo-cfa-ffb`, « Aucun club »).
- **Piège : ne pas tester ni livrer un build `--profile` avec Firebase Auth sur le web.** `firebase_core_web` décide du mode
  debug par `!bool.fromEnvironment('dart.vm.product')` (vrai en profile) alors que `firebase_auth_web` utilise `kDebugMode`
  (faux en profile) : en profile, les trois écouteurs d'état partagent la clé `'no-op'`, le suivant désabonne le précédent et
  le flux des comptes n'émet jamais. L'application reste alors sur l'écran de démarrage (constaté 2026-10-17, `flutter build
  web --profile`). En debug (`flutter run`, DDC) et en release (`scripts/build_web.sh`) le flux émet. Le build de production
  est un release : il atteint `#/sign-in`. L'`AuthCubit` borne en plus l'attente (`startupTimeout`, 20 s) : sans réponse, l'écran
  « Service injoignable » et « Réessayer » remplacent un écran de démarrage éternel.
- **Contre l'émulateur Auth** : `scripts/rules_test/auth_emulator.test.mjs` (lancé avec les tests de règles, `scripts/rules_test.sh`).
  Il prouve les codes d'erreur et les courriels que le code Dart suppose (adresse non vérifiée à la création, mauvais mot de passe
  et adresse inconnue regroupés par l'application, 6 caractères seulement côté serveur, courriels de vérification et de
  réinitialisation émis par le service, adresse inconnue sans courriel). **Justification de l'absence de test du code Dart
  contre l'émulateur** : `firebase_auth` est un plugin natif, absent sous `flutter test` ; un test d'intégration sur appareil ou
  navigateur seul entre dans un garde-fou déterministe : c'est la fumée ci-dessus.

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

### Mutations de la relecture FB4c (2026-10-18)

- Retirer `attemptComplete()` et `noFieldLost()` de la copie des règles fait échouer `progress.test.mjs` (passage minimal, champ supprimé ou vidé, bloc acquis / bilan / « Vu » minimal).
- Remplacer le départage `a.id.compareTo(b.id)` de `AttemptDocument.compare` par `return 0` fait échouer le test direct de `compare` (le test d'égalité sur le faux store ne le voyait pas : le faux trie par chemin).
- Faire écrire `_store.current` par `ReloadRules` sans `isCurrent` fait échouer les deux tests de `auth_rules_reload_test.dart` (chargements finissant à l'envers, déconnexion pendant le chargement).

### Mutations du troisième tour de relecture FB4c (2026-10-18)

- Remplacer `isoText(l[i].effectiveFrom)` par « texte de 40 caractères au plus » dans `changeAt` fait échouer `bounds.test.mjs` (« chaque date est un texte ISO exact (calendrier compris), même la dixième » : `'pas une date'`, mois 13, jour 32, heure 24, au rang 0, 4 et 9). Avec dix éléments, `isoText` joué dix fois reste dans le budget d'expressions (`bounds.test.mjs`, 10 changements acceptés ; `budget.test.mjs` vert).
- Retirer les plages du motif `isoText` (mois, jour, heure, minute, seconde en `[0-9]{2}`) fait échouer `bounds.test.mjs` et `progress.test.mjs` (« `date` : ISO 8601… ») ainsi que « dates : le texte exact des codecs ».
- Faire que `DocumentValues._keepsCalendar` rende toujours `true` fait échouer `document_values_test` (« a calendar-invalid text is rejected… » : 30 février, 31 avril, `2026-13-45T99:99:99`).

### Mutations du second tour de relecture FB4c (2026-10-18)

- Retirer `&& current()` du chemin d'échec de `ReloadRules` fait échouer les deux nouveaux tests de `auth_rules_reload_test.dart` (chargement tardif en échec après bascule de club, puis après déconnexion).
- Retirer `noFieldLost()` de la mise à jour des **bilans** ou des **acquittements** fait échouer `progress.test.mjs` (« une mise à jour ne supprime ni ne vide un champ d'un bilan ou d'un « Vu » »).
- `presInt(d, 'total', 1, 17)` fait échouer `progress.test.mjs` (`potted: 5, total: 17` refusé). `presInt(d, 'potted', 0, 100)` est un mutant **équivalent** (`potted <= total <= 16`), voir l'ADR 0024.
- Remplacer `isoText` par « texte de 1 à 40 caractères » dans `presStamp` fait échouer `progress.test.mjs` (dates `'zz'`, date sans heure, fuseau décalé, fraction trop longue) ; dans `optStamp`, `bounds.test.mjs` (saison avec `startDate: 'zz'` ou `closedOn` sans heure).
- Trier avant de décoder (`_ordered`) fait échouer « attempts with a malformed sort field keep the rest » (`firestore_progress_repositories_test`).
- `_byDate(recordedAt…, nullLast: false → true)` fait échouer « compare: a pass without device stamp comes before… ».

## Lot FB5a : hors ligne, cache local, pastille, SDK local (2026-10-19)

- **SDK web local** : `sync_firebase_sdk_test.dart` (script rejoué dans un faux dépôt : version du plugin, fichier modifié, manquant ou en trop, carte
  d'import absente, fausse, tardive, import interne non couvert, plugin qui ne charge plus Firestore comme prévu, vecteurs SHA-256 connus) ;
  `pwa_test.dart` (carte d'import absente ou qui vise autre chose que `./firebasejs/`, script externe voisin, build sans SDK au précache) ;
  `platform_privacy_test.dart` (la page n'a d'URL absolue que les clés de la carte) ; la fumée du build compilé et le parcours navigateur
  refusent gstatic.com et exigent les trois fichiers servis en local. **Rouge vu** : les tests `pwa_test` de `verify` échouent sur l'ancien
  `pwa.dart` (6 échecs) ; la fumée a été relancée verte avec gstatic refusé.
- **Persistance** : `firebase_sdk_gateway_test.dart` (réglage persistant multi-onglets, ordre : initialisation, réglage, puis émulateurs).
- **Cache local** : `local_data_guard_test.dart` (propriétaire, autre compte, échec d'effacement qui lève, déconnexion, envois en attente),
  `firestore_local_data_cache_test.dart` (ordre `terminate` puis `clearPersistence`, rechargement séparé), `auth_cubit_test.dart` (groupe « local
  data cache », dont la session perdue ailleurs qui ne vide pas), BDD `sync_and_local_data.feature` (déconnexion qui vide le cache, avec envois
  en attente : confirmation d'abord, annulation, confirmation). **Couvert par le vrai SDK** : la fumée du build compilé (`web_smoke.test.mjs`) vérifie qu'une base IndexedDB `firestore/…` existe après la
  connexion (persistance **active**), puis que la déconnexion recharge la page et qu'aucune base `firestore/…` ne subsiste (`terminate` +
  `clearPersistence` réels). **Non couvert** : le natif ; le cache vidé d'écritures réellement en attente (aucun Firestore émulé dans la fumée).
- **Pastille** : `sync_state_test.dart` (dérivation, priorités), `sync_status_cubit_test.dart` (écriture hors ligne puis retour du réseau, refus
  tardif des règles), `sync_status_chip_test.dart` (libellés fr/en, région vive, bleu-tapis), BDD (à jour, hors ligne, en attente, retour,
  refus), Widgetbook (`sync_status_use_cases.dart`). **Non couvert** : `navigator.onLine` réel (liaison web sans test, comme `offline.js`).
- **Écritures hors ligne** : `firestore_progress_repositories_test.dart` (**rouge vu** : l'ancien test « limite connue » échoue dès que `upsert`
  ne lit plus le serveur ; remplacé par : création hors ligne d'un bloc acquis, d'un bilan, d'un « Vu » avec un stock dont la lecture d'un
  document absent échoue ; remplacement qui garde propriétaire et auteur du « Vu » hors ligne ; passage absent du cache ; fiche absente refusée),
  `firestore_planning_repositories_test.dart` (saisie libre créée hors ligne, saisie liée refusée proprement), `peek` sur le double, le magasin
  Firestore et l'accès au SDK (`unavailable` = absent du cache), `planning.test.mjs` (création à l'aveugle d'une saisie libre déjà présente :
  refusée, date d'origine intacte). Aucune règle ne change : les tests d'attaque existants (`progress.test.mjs`) gardent propriétaire et auteur.
- **Workflows** : `workflows_test.dart` (voir quality-gates.md).

