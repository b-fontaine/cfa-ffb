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
  l'état local d'un écran est remis à zéro quand le club change, conservé quand il reste le même (y compris quand les mêmes groupes et fiches sont relus dans un autre ordre). Il ne referme **pas** les blocs des pages ouvertes : la fermeture des écoutes est testée dans `club_store_test` (`activeWatchers == 0` juste après le changement de portée, sans événement semé ; même ensemble dans un autre ordre : rien ne ferme) et `relay_stream_test` (`recheck`), la réouverture dans `live_reload_test` (une mutation sur chacune des règles du garde anti-boucle : sans garde, garde jamais remis à zéro par une donnée, jamais remis à zéro par `restart`).
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

## Lot FB5b : flux temps réel, règle de conflit, hors ligne des écritures (2026-10-19)

- **Flux du port** : `document_store_watch_contract.dart` (un état courant puis un état par changement pour un document, une collection, une requête
  par égalité, `array-contains-any` ou plusieurs égalités ; indépendance des flux ; annulation ; lot final complet) joué sur le double en mémoire et
  sur le vrai `FirestoreDocumentStore` devant un faux Firestore. **Rouge vu** : les méthodes n'existaient pas (échec de compilation du contrat).
  Spécificités : le double (`in_memory_document_store_test` : un lot en **un seul** état, aucun état si rien ne change, `seed`/`remove` notifient,
  `activeWatchers` revient à zéro à l'annulation, `revoke` ferme en `permissionDenied` et refuse les lectures et écoutes suivantes jusqu'à
  `restore`, `failing` refuse l'ouverture) ; le magasin Firestore (`firestore_document_store_test`, accès scripté : décodage et métadonnées,
  tri par identifiant, chaque filtre ouvre la bonne requête, une erreur est un `StoreFailure` qui ferme **ce** flux seulement, l'annulation relâche
  l'écoute) ; `relay_stream_test`, `combine_latest_test`, `changes_test`, `live_reload_test`, `change_feed_test` (briques : erreur livrée une fois puis
  fermeture, annulation propagée, pause, états identiques écartés, relectures fondues, annonces d'une unité de travail retenues jusqu'à sa fin, annulation
  comprise).
- **Faux Firestore : ce que le contrat des flux ne prouve PAS** (dit une fois ici) : il livre un lot **document par document** (le SDK réel en un seul état :
  prouvé par l'émulateur) ; il ne trie pas les collections suivies (le magasin les trie) ; ses métadonnées sont celles d'un serveur toujours joint
  (`fromCache` faux, `hasPendingWrites` faux) ; il n'applique aucune règle (aucun `permission-denied`, d'où `InMemoryDocumentStore.revoke`) ; il n'a
  ni cache hors ligne ni reconnexion ; il n'isole pas les transactions (`isolatedTransactions: false` dans la règle de conflit).
- **Contrat des dépôts** : `repository_watch_contract.dart` (élèves, groupes avec leurs appartenances, séances planifiées, séances données, passages,
  blocs acquis, « Vu », bilans ; tout le club et par élève ou groupe ; jamais deux états égaux de suite ; deux abonnés ; annulation) sur mémoire, drift et
  Firestore (faux). **Par rôle** : `firestore_watch_roles_test` lit le **journal des écoutes** du double (`watchLog`) : un gestionnaire suit les
  collections, un enseignant ses groupes un par un (`array-contains-any` par tranches de 30), un parent ses fiches liées et **aucune** écoute de ce que les
  règles cachent ; un refus ferme ce flux seulement ; sans club actif, `denied` sans chemin deviné ; un flux se ferme quand le club ou le rôle change.
- **Contre l'émulateur** (`scripts/rules_test/watch.test.mjs`, deux clients, vraies règles, dans `rules_test.sh`) : un client écrit, l'autre reçoit ; un
  enseignant ne reçoit que son groupe ; un lot arrive en un état ; entrée et sortie d'une fiche du groupe (`array-contains-any`) ; `permission-denied`
  sur le flux qui se ferme, sans toucher les autres flux du client ; un membre **retiré** perd ses écoutes (sur l'émulateur, immédiatement ; le service
  réel peut tarder : non éprouvé) ; annulation ; `hasPendingWrites` puis confirmation ; `disableNetwork`/`enableNetwork` : état conservé hors ligne,
  rattrapage à la reconnexion, écriture mise en file reçue par l'autre client.
- **Règle de conflit** : `conflict_contract.dart` (une ligne de la table de l'ADR par test, `C1` à `C13`, plus les limites `L1` à `L4` en tests de
  **caractérisation**), joué sur le faux Firestore et sur le double du stock avec **deux appareils** (deux `ClubStore`, deux sessions) ; `conflicts.test.mjs`
  contre l'émulateur avec deux clients (`Promise.all`) : dernier écrit gagne = l'une des deux écritures, entière ; unions atomiques ; rejeu d'un passage
  refusé ; « Vu » au nom d'un collègue refusé ; `set merge` recrée un document supprimé (limite) ; `E1` à `E4` pour la saisie liée hors ligne avec le vrai
  SDK déconnecté. Les assertions `anyOf` des « dernier écrit gagne » sont voulues : l'ordre d'arrivée au serveur n'est pas déterministe.
- **Écritures non bloquantes** : `club_store_test` (accusé dans le délai, hors délai confié au suivi, réseau connu coupé ou envoi en attente : pas
  d'attente, refus tardif vers la pastille, refus dans le délai pour l'appelant, reprise `ifRefused` et son échec, `mayAwaitServer`, transaction sans
  réponse = `unavailable`, sans suivi : comportement d'avant) ; `firestore_planning_repositories_test` (saisie liée : réseau coupé, transaction qui échoue,
  en ligne inchangé, saisie créée entre-temps → refus → union, deux appareils hors ligne, cache qui connaît la saisie, refus véritable signalé). **Rouge vu** :
  les tests de `ClubStore` échouaient à la compilation (paramètres absents) et les 6 tests de saisie liée à l'exécution.
- **BDD multi-appareils** (`live_sync.feature`, 6 scénarios) : `Given the club data lives on a server shared with other devices` branche les dépôts
  Firestore sur un serveur en mémoire que partagent l'appareil de l'écran (`DeviceDocumentStore`) et **un autre appareil** (`OtherDevice` : second graphe
  get_it complet, autre session, mêmes dépôts) ; les `Given` d'amorçage et les étapes « un autre appareil écrit » passent par cet autre appareil.
  **Rouge vu** : sans abonnement dans les trois blocs, 5 scénarios sur 6 échouent ; sans libération dans `close`, « Leaving a screen leaves no
  subscription behind » échoue. `DeviceDocumentStore` (testé : `device_document_store_test`) : **hors ligne**, les lectures du serveur échouent en
  `unavailable`, les flux retiennent leur dernier événement jusqu'à la reconnexion, les lots sont mis en file dans l'ordre ; **limites du double** : pas de cache
  local (une écriture hors ligne n'est visible qu'à la reconnexion), aucune règle, coupure tout ou rien ; le vrai SDK hors ligne est éprouvé par
  `watch.test.mjs` et `conflicts.test.mjs`.
- **Interface** : `club_scoped_test` (un nouveau rôle dans le même club reconstruit l'écran ; **mutation** : clé sans rôle, le test échoue) ; trois
  tests de bloc ou de cubit par écran abonné (abonnement une seule fois, relecture en place sans état de chargement, rafale fondue en une relecture,
  refus affiché puis repris, « Réessayer » qui rouvre l'écoute, fermeture).
- **Effets sur les tests existants** : quatre scénarios (`screen_navigation.feature` : suppression et retour d'une séance planifiée ; `session_guide.feature`
  : retour au planificateur) lançaient l'application **avant** d'y amorcer une séance ; l'accueil se met désormais à jour et déplaçait le bouton
  « Plan a session » sous la barre de navigation de la fenêtre de test. Les `Given` passent avant « the app is running ».
- **Mutations à la main** : abonnement supprimé dans `StudentSheetBloc`, `StudentsBloc`, `UpcomingSessionsCubit` (5 scénarios BDD rouges) ;
  `stop` retiré de `StudentSheetBloc.close` (scénario de fuite rouge) ; rôle retiré de la clé de `ClubScoped` (test rouge).


## Lot FB6 : espace élève et parent, lecture seule (2026-10-19)

- **BDD d'abord, rouge consigné** : `test/bdd/family_space.feature` (12 scénarios, dont 10 écrits avant le code : arrivée du parent sur le parcours de son enfant et les séances de son groupe, parent
  de deux enfants qui bascule sans mélanger, aucune action d'animateur et routes refusées, la saisie de l'animateur qui arrive sans recharger, une séance planifiée qui
  arrive, requêtes limitées aux enfants liés, élève de 15 ans, écran passé en direct à « Accès retiré », refus du serveur distinct d'un service injoignable, hors ligne puis rattrapage) écrit
  **avant** le code et joué sur l'application **d'avant le lot** (arbre de travail à part, `git worktree` du commit FB5 : 9 des 10 scénarios d'alors rouges, le seul vert étant
  la garde de route, déjà en place) ; **les 2 autres** (« second enfant suivi en direct », « retrait d'un seul des deux liens ») ont été ajoutés ensuite et **n'ont pas été vus rouges** ; puis les 12 verts sur le code. Les scénarios tournent sur le serveur partagé de FB5b (`the club data lives on a server shared with
  other devices`) : l'application est un **parent** (dépôts Firestore, comme avec `DATA_BACKEND=firestore`), l'animateur est **un autre appareil** du même club.
- **Doubles ajoutés** : `DeviceDocumentStore.requests` (journal de **tout ce que l'appareil de la scène demande** au serveur : lectures, écoutes, écritures ; les autres
  appareils n'y figurent pas, contrairement à `InMemoryDocumentStore.watchLog`) ; `FamilyWorld` (compte lié à des fiches et à leurs groupes du jour, retrait de l'accès).
  Limites héritées : le double n'applique aucune règle (le retrait de l'accès est simulé par `revoke`, la preuve sous les vraies règles est `family.test.mjs` et le
  parcours navigateur).
- **Isolation, trois niveaux** : (1) BDD « requêtes limitées » : le journal de l'appareil ne contient l'identifiant ni de Marc ni de Tom, aucune écriture, aucune liste
  (élèves, camarades, séances), rien de ce que les règles cachent ; (2) `get_family_space_test` sur les **vrais dépôts Firestore** du rôle : mêmes assertions, plus **l'égalité
  du journal avec `scripts/rules_test/family_reads.json`** (toute demande hors liste ou toute entrée de la liste que l'application ne demande plus échoue) ;
  (3) `scripts/rules_test/family.test.mjs` contre l'**émulateur et les vraies règles** (94 tests) : la liste `famille` et la liste `connexion` sont permises à un parent et à un élève ;
  la liste `interdit` (autre fiche, autre groupe, autre club, listes, saisies, bilans, « Vu », appartenances, archives, membres) est refusée aux deux ; un parent de deux enfants
  lit les deux fiches et pas un camarade du même groupe ; **aucune écriture** (14 tentatives par rôle, dont s'ajouter une fiche ou changer son rôle) ; un `member` supprimé
  retire l'accès : les nouvelles lectures sont refusées, l'écoute ouverte ne reçoit `permission-denied` qu'à la modification suivante d'une séance ou du document de ce groupe (un renommage suffit) ou du document écouté ; le cache de l'appareil est vidé à la déconnexion ; une fiche retirée du lien est refusée, l'autre reste lisible ; **limite connue côté serveur** (« known limit », mesurée, durable : ne casse pas avec FB7) : un groupe retiré du lien reste servi à l'écoute ouverte et à la relecture faite sur la même instance du client (témoin : la même lecture depuis une autre instance est refusée), refusé à la modification suivante d'une de ses séances, refusé à toute lecture neuve ; un passage saisi par l'animateur arrive à l'écoute du parent.
  **Mutation** : `linkedTo` rendue vraie pour tout parent ou élève sur une copie des règles : 13 tests rouges, restaurée.
- **Unitaires** : `get_family_space_test` (ordre du lien, séances des groupes du compte de la veille (exclue) au lendemain (inclus), à 23:59 comme à 9:30, triées par date quel que soit l'ordre des identifiants ou du dépôt, plafonnées à 5 avec les bornes 4, 5 et 6 contre la valeur littérale, fiche absente ou déliée ignorée, enseignant refusé,
  refus du serveur ≠ injoignable, **le temps réel suit chacun des deux enfants** : mutation `take(1)` sur `WatchFamilySpace` = rouge) ; `check_family_access_test` (lien absent, vide ou sans fiche de la session = retiré ; retrait partiel = accès aux fiches restantes ; lien illisible faute de réseau = inchangé ; **« known limit »** : un groupe retiré du lien n'est pas vu par `CheckFamilyAccess` avant FB7, test de caractérisation à double qui doit casser à la correction, sans mesure à l'émulateur) ; `family_space_cubit_test` (**« known limit »** : l'écran garde les séances d'un groupe retiré du lien jusqu'à FB7, double du lien, à casser avec FB7 ; sélection conservée aux relectures et repliée si l'élève est délié, un seul abonnement, **refus avec lien
  existant = refusé**, **accès retiré** (règle du domaine, simulée ici) avec l'abonnement relâché et aucune donnée affichée, plus aucune relecture ensuite, injoignable
  avec données = dernières données **périmées** affichées, premier chargement injoignable = échec puis « Réessayer », libération à la fermeture) ; `family_space_view_test`
  (pas d'action d'écriture : aucun bouton, champ ni interrupteur ; puces de 48 dp, sémantique « bouton sélectionné », prénoms identiques numérotés, écran étroit à texte
  double) ; `my_children_page_test` (états, fr et en, « Accès refusé » distinct) ; `store_own_link_source_test` ; `data_backend_module_test` (le module ne reçoit aucun rôle : défaut drift vérifié, `DATA_BACKEND=firestore` donne Firestore à tous : [repositories-firestore-plan.md](repositories-firestore-plan.md)), `homonymRanks` (rang seulement, aucun texte) et l'erreur imprévue du cubit (état d'erreur, jamais une exception qui remonte). Le garde de `get_student_showcase_test` (« la tranche
  n'importe rien qui puisse fuiter ») est **resserré, pas abaissé** : l'agrégat `Group` et son dépôt (les appartenances sont les camarades) restent interdits ; le seul import
  de l'entité groupe permis est le port étroit `GroupNames` (noms seulement), vérifié ligne à ligne.
- **Parcours navigateur** (`scripts/emulator_e2e.sh`, 7 tests dont 4 nouveaux, application en mode debug + émulateurs + graine étendue ; l'« autre appareil » est un client Node
  connecté à l'émulateur Auth, **sous les vraies règles**) : parent de deux enfants (puces, séances de son groupe seulement, ni Marc ni Camille ni la séance des adultes, aucune
  action d'animateur, cinq adresses d'animateur tapées à la main ramenées à `/my-children`) ; saisie d'un enseignant **sans recharger** (même `performance.timeOrigin`) et enfants
  non mélangés ; élève de 15 ans ; retrait du lien par le directeur. **Rouge utile au premier passage** : « Accès retiré » ne venait pas, les lectures étant servies par les écoutes
  ouvertes (ADR 0024 notes FB6) ; corrigé et rejoué vert. Les puces de choix n'ont qu'une **étiquette** d'accessibilité (`aria-label`), pas de texte : le test les cherche par étiquette
  et lit « texte + étiquettes » pour affirmer ce qui est absent. Ne pas modifier `emulator_e2e.sh` pendant qu'il tourne (bash le relit en cours d'exécution).
- **Piège d'outillage** : un test qui échoue dans un fichier de widgets peut laisser `flutter test` tourner à 100 % de processeur au lieu de rendre la main (`Bad state: Cannot close sink
  while adding stream`) ; tuer le `flutter_tester` par son PID (jamais `pkill -f` d'un motif de sa propre ligne). Annuler l'abonnement d'un flux rend la main à la boucle **réelle** :
  `await tester.runAsync(pumpEventQueue)` avant d'attendre l'état « accès retiré ».
- **Widgetbook** : `family_space_use_cases.dart` (espace complet avec curseurs : élèves liés, séances, hors ligne ; sélecteur ; prochaines séances ; message d'accès) et la
  page `MyChildrenPage` branchée sur le nouveau cubit.

## Lot FB7, partie A : moteur d'import vers un club Firestore (2026-10-20)

Voir l'[ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md) (notes FB7a) et le [plan des dépôts](repositories-firestore-plan.md). Le moteur est du **domaine pur** (`features/backup_data/domain/club_import/`) ; ses tests ne touchent aucun SDK Firebase et aucun projet réel : faux stock en mémoire, `fake_cloud_firestore`, émulateurs `demo-cfa-ffb`.

**BDD d'abord, rouge vu.** `app/test/bdd/club_import.feature` (12 scénarios, dont « reprendre avec un autre rattachement de groupes est refusé car le plan a changé » (`planChanged`, marqueur inchangé) ; premiers 8 : import complet par le directeur, reprise après coupure = import complet, rejeu du même fichier, séance sans groupe, enseignant hors périmètre, fusion de groupes sans choix, élèves effacés, plafond quotidien) a été écrit et généré **avant** tout code : `flutter test test/bdd/club_import_test.dart` → **8 échecs** (`UnimplementedError` des étapes générées), le 2026-10-20 ; les étapes (`test/step/…`) puis le moteur ont fait passer les 8 au vert. Monde des scénarios : `test/support/import_world.dart` (`ImportWorld`) sur `RulesLiteStore`, un **faux serveur** qui applique ce que les règles imposent au moteur (marqueur : création avec `done == 1`, avancement d'exactement un ; aucun écrasement ; un marqueur par lot ; au plus 400 écritures et 18 fiches distinctes ; `createdAt` = date du serveur **du lot**) et simule les coupures (réseau coupé avant un lot, accusé perdu après un lot appliqué).

**Tests unitaires et de contrat** (`test/unit/features/backup_data/domain/club_import/`, `test/unit/app/`, `test/unit/shared/`) :

| Fichier | Prouve |
|---|---|
| `club_import_planner_test.dart` (51 ; `club_import_planner_visibility_test.dart` : reprise d'un enseignant alors qu'une fiche hors de ses groupes est apparue entre-temps = même plan, reprise au lot suivant, le lot fautif est refusé par les règles et signalé par le moteur) | écritures par catégorie, identifiants conservés, lots (≤ 399 écritures, unités atomiques, fiche avant ses données, ≤ 18 fiches distinctes), `recordedAt` strictement croissant dans l'ordre du fichier, déterminisme et indépendance vis-à-vis de l'existant, correspondance des groupes (identité, association, identifiant de saisie qui suit le groupe, fusion refusée puis confirmée, public, saison close, date hors saison, saison rouverte), séances et élèves sans groupe (choix, ignorer, choix invalide), droits (enseignant : pas de groupe créé, pas hors périmètre, fiche à appartenance fermée ou décalée refusée **avec ses passages**), élèves effacés (détection, confirmation exacte, fichier plus récent, effacement en cours, import en cours non redemandé), marqueur (terminé, reprise, autre plan), coût (jours, avertissements), rapport sans prénom |
| `import_integrity_test.dart` (14) | doublons de chaque collection (et des appartenances), références (groupe, saison, séance, présent, passage orphelin, archive d'une saison ouverte), bornes du domaine et des règles (nom, titre, présents, caractères et non unités UTF-16, identifiants, date refusée par le serveur, numéro d'exercice), aucune donnée personnelle |
| `club_import_runner_test.dart` (15) | ordre des lots, création puis avancement du marqueur, coupure puis reprise = import complet, **accusé perdu d'un lot appliqué : jamais écrit deux fois**, lot refusé car le marqueur a avancé = succès, refus des règles, budget du jour (arrêt avant le lot qui dépasse, reprise un autre jour, un lot au moins), plan non exécutable, autre plan, import terminé |
| `prepare_club_import_test.dart` (13) | fichier illisible, version inconnue, valeur invalide, trop grand : **plan bloqué, jamais une erreur** ; intégrité en entier puis catalogue ; rôle et club ; empreinte = SHA-256 du fichier |
| `club_import_formats_test.dart` (13) | les cinq fichiers `app/test/fixtures/backup/club-small-v1…v5.json` (fictifs) sont **ce que le code courant écrit** (format d'export inchangé, `UPDATE_FIXTURES=1` les réécrit), chacun est lu, planifié et écrit |
| `firestore_club_import_store_test.dart` (20) | champs **exacts** de chaque document écrit, acquittement signé de l'auteur, marqueur sans donnée personnelle, jamais d'écrasement (fiche existante : seuls les groupes manquants), second fichier sur un club qui en contient un autre, lecture du club par rôle (liste pour le gestionnaire, un groupe à la fois pour l'enseignant, rien de personnel), refus et absence de réponse, et **un import complet sur le vrai `FirestoreDocumentStore` (faux Firestore), relu par les vrais dépôts et comparé au fichier** |
| `import_report_text_test.dart` (6), `sha256_test.dart` (5), `document_ids_test.dart` (3), `field_limits_test.dart` (+2) | textes fr + en de chaque code, SHA-256 (vecteurs de référence, **aussi sous dart2js**), identifiants communs avec les dépôts, bornes et expression de date égales à `firestore.rules` |

**Règles contre l'émulateur** (`scripts/rules_test/`) : `matrix.test.mjs` (suite `imports`, 9 tests : création de **son** marqueur, attaque (marqueur au nom d'un autre), relecture de son seul marqueur, avancement par son auteur seul, suppression par rôle) et `import.test.mjs` (56 tests : dont la course de deux lots simultanés (30 essais, 0 écrasement), l'uid à métacaractères, une séance et un groupe préexistants hors visibilité de l'enseignant,  l'absence d'écrasement par collection et le marqueur lié à son auteur). `scripts/rules_test.sh` appelle d'abord `app/tool/import_plan_fixture.dart` (le **planificateur de l'application** sur des sauvegardes fictives, mêmes codecs que l'application : `ClubImportOperations`) dans un dossier temporaire (`IMPORT_PLAN_DIR`) : rien n'est versionné, rien ne peut dériver. `import.test.mjs` joue : un fichier de **1992 écritures** (10 lots) par le directeur puis par l'administrateur, relu en entier et comparé au plan, passages relus dans l'ordre du fichier, `createdAt` du lot ; l'enseignant dans son groupe (66 écritures ; 30 fiches neuves en deux lots), refusé hors périmètre, pour les saisons et groupes, et sur le rôle du marqueur ; le **miroir du plan** (12 écritures permises acceptées, 48 refusées refusées une à une et acceptées du directeur) ; la **convergence** (rejeu, saut, rejeu par un autre appareil, reprise après N lots par le même compte (autre appareil), import terminé, passage non écrasé) ; la limite des **20 documents lus par lot** (17 fiches neuves d'un enseignant passent, 18 sont refusées).

**Limites dites.** (1) Les doubles en mémoire n'ont ni cache local ni hors ligne : la coupure est tout ou rien ; le hors ligne réel est du parcours navigateur (partie B). (2) `RulesLiteStore` est **plus strict** que les règles (aucun écrasement) et ne rejoue pas leur grammaire : la vérité sur les règles est l'émulateur. (3) L'émulateur met un temps considérable à **refuser** un lot de 400 créations : les refus se prouvent sur un extrait (documenté dans `import.test.mjs`) ; les lots acceptés et les rejeux de documents existants sont instantanés. (4) Les 20 lectures par lot ont été **mesurées à l'émulateur** (directeur 19 fiches, administrateur et enseignant 18) ; la production applique la même limite documentée par Firebase.

### Mutations à la main (FB7, partie A, 2026-10-20)

Chaque mutation est appliquée à une copie, la suite visée doit échouer, puis le fichier est restauré (aucune n'est conservée).

| Mutation | Test qui échoue |
|---|---|
| plan : retirer le budget de fiches distinctes d'un lot | `club_import_planner_test` « a lot cites 18 distinct students at most » |
| plan : `recordedAt` constant | « attempts keep the file order, recordedAt strictly increasing » |
| plan : les passages d'une fiche refusée restent permis | « a teacher cannot import a shifted student, nor his data » (et, contre les règles, `import.test.mjs` « ce que le plan permet… ») |
| plan : fusion de groupes sans confirmation | « two file groups on one club group are refused without a merge choice » |
| exécution : repartir du lot 0 au lieu de `done` | `club_import_runner_test` « an unacknowledged lot… not written twice » |
| exécution : ignorer le budget du jour | « a budget smaller than one lot still writes one lot per run » |
| écriture : réécrire un document existant | `firestore_club_import_store_test` « a document that exists is left as it is » |
| règle : `done == résultat + 1` devient `done > résultat` | `import.test.mjs` « un lot sauté est refusé… » |
| règle : `importStampValid()` retirée d'une forme (ou rendue toujours vraie) | `import.test.mjs` « … n'est jamais écrasé » (la collection concernée) |
| règle : l'avancement n'exige plus l'auteur du marqueur (identifiant sans `uid`) | `import.test.mjs` « le marqueur d'import est lié à son auteur » (T1, T2, T3) et `matrix.test.mjs` suite `imports` (ATTAQUE, avancement d'un autre) |
| règle : le marqueur redevient `imports/{empreinte}` (création sous l'empreinte seule permise) | `import.test.mjs` T1 et `matrix.test.mjs` « ATTAQUE : personne ne crée un marqueur au nom d'un autre auteur » |
| règle : `importStampValid()` sans `resource.data.importedAt < request.time` (marque égale acceptée en mise à jour) | `import.test.mjs` « deux lots simultanés sur les mêmes documents : jamais deux acceptés (30 essais) » (2 lots acceptés en parallèle) |
| règle : lecture du marqueur par `markerId.matches('…_' + request.auth.uid)` (regex dynamique) | `import.test.mjs` « un compte dont l'uid est « .* » ne lit que son propre marqueur » (4 uid à métacaractères) |
| planificateur : le contrôle `marker.planId != planId` retiré | scénario BDD « Reprendre avec un autre rattachement de groupes est refusé car le plan a changé » |
| règle : `importStampValid()` laisse passer `importedAt: null` sur un document sans marque | `import.test.mjs` « une mise à jour ne pose pas importedAt, pas même à null » |
| planificateur : `planId` sans le contenu des écritures ni les décisions | `club_import_planner_edges_test` « attaching the orphan session to another group changes the plan id », `club_import_planner_test` « the plan identity… » |
| planificateur : les fiches invisibles d'un enseignant ne sont plus comptées | `club_import_planner_visibility_test`, `prepare_club_import_test` « a fiche of the file that exists outside her groups… » |
| magasin : le marqueur relu par `get` (cache) au lieu de `getFromServer` | `firestore_club_import_store_test` « the marker is read from the server, never from the cache » |
| runner : `spent + cost > limit` devient `>=` | `club_import_runner_test` « a lot that lands exactly on the ceiling is written » |
| texte : séparateur « : » codé en dur | `import_report_text_test` (littéraux fr et en) |
| runner : le compte du jour n'est plus lu (`spent = 0`) | `club_import_runner_test` « two runs the same day… » et le scénario « Reprendre le même jour n'ajoute aucune écriture » |
| règle : retirer `done == 1` à la création | `matrix.test.mjs` suite `imports` (création avec `done` autre que 1) |
| règle : suppression du marqueur permise au directeur | suite `imports` (suppression : personne) |
| règle : `isFamily` ajouté à `mayImport` | suite `imports` (création, lecture, avancement) |
| règle : `planId` non figé à l'avancement | suite `imports` (avancement : champ changé refusé) |

La condition `resource.data.state == 'running'` de la règle d'avancement est **redondante** avec `done <= lots` : la retirer ne fait échouer aucun test ; elle est gardée en défense en profondeur.
