# Architecture : Clean Architecture + Feature-Sliced Design

Le code de `app/lib/` est organisé en **couches FSD** ; à l'intérieur d'une slice,
on applique les **segments Clean** (`domain`, `data`, `presentation`).
Les règles ci-dessous sont vérifiées par `app/tool/check_architecture.dart`
(logique dans `app/tool/architecture/architecture_rules.dart`, testée par
`app/test/tool/architecture_rules_test.dart`).

## Couches (de la plus haute à la plus basse)

| Couche | Rôle | Exemple dans le projet |
|---|---|---|
| `app` | Câblage : `App`, routeur go_router, DI get_it/injectable | `app/app.dart`, `app/router.dart`, `app/di/injection.dart` |
| `pages` | Écrans routables, composent widgets et features | `pages/home`, `pages/session_planner`, `pages/more` |
| `widgets` | Blocs d'interface réutilisables et autonomes, sans logique métier | `widgets/session_list` |
| `features` | Actions utilisateur ayant une valeur métier (cas d'usage + Bloc + UI) | `features/plan_session` |
| `entities` | Concepts métier (modèle, port de repository, implémentation de données) | `entities/session` |
| `shared` | Code transverse : `lib` (Dart pur : noyau partagé), `ui`, `l10n` | `shared/lib/identifiers.dart`, `shared/ui`, `shared/l10n` |

`lib/main.dart` est le point d'entrée ; il est traité comme la couche `app`.

## Règles d'import (toutes vérifiées automatiquement)

1. **Vers le bas uniquement** : une couche n'importe que des couches strictement
   inférieures (`app` → `pages` → `widgets` → `features` → `entities` → `shared`).
2. **Jamais entre slices d'une même couche** (`features/a` ne connaît pas
   `features/b`). Composer au niveau supérieur (`pages` ou `app`).
3. **Segments** dans une slice (`<couche>/<slice>/<segment>/…`) :
   - `domain` : Dart pur. N'importe que `domain` (ou `shared/lib`) et, côté SDK,
     `dart:core/async/collection/convert/math`, `freezed_annotation`, `injectable`, `meta`.
     **Aucun** `flutter`, `flutter_bloc`, `go_router`, `get_it`, `dart:io`, `dart:ui`.
   - `data` : implémente les ports du `domain`. Importe `domain` (et sa propre `data`).
   - `presentation` : Bloc/Cubit, widgets. Importe `domain`, jamais `data`.
4. Imports **absolus** `package:billard_cfa/...` uniquement (pas d'import relatif).
5. Un fichier hors `main.dart` / `app/` / `shared/` doit être dans
   `<couche>/<slice>/<segment>/` avec un segment connu.
6. Seule la couche `app` peut relier `presentation` et `data` (câblage DI).
7. **Segments de `shared`** : `shared/lib` (noyau Dart pur) n'importe que
   `shared/lib` ; `shared/persistence` n'importe que `shared/lib` et n'est
   importé que par `data` et la couche `app` (jamais par `presentation`,
   `domain`, `shared/ui` ni `shared/l10n`) ; `domain` n'importe que `shared/lib`.

8. **Paquet `pdf`** (ADR 0021) : seule la couche `data` de `features/export_sheet`
   importe `package:pdf/pdf.dart` (API bas niveau) ; `package:pdf/widgets.dart`
   (+905 Ko de code compilé), `package:pdf/src/` et `package:printing/` (pdf.js
   chargé depuis un CDN, incompatible avec le hors ligne) sont interdits partout
   dans `lib/` (les tests peuvent lire `pdf/src` : table des glyphes).

9. **SDK de plateforme** : `firebase_auth`, `firebase_core` et `cloud_firestore`
   ne sont importés que sous `lib/app/platform/` (aujourd'hui
   `firebase_auth_sdk.dart`, `firebase_sdk_gateway.dart` et `firestore_document_store.dart` ; `firebase_core`
   aussi par `lib/app/firebase_options.dart`, fichier généré qui n'en prend que
   `FirebaseOptions`) ; `shared_preferences` seulement par
   `lib/app/platform/shared_preferences_key_value_store.dart`. Le reste du code
   passe par des ports (`AuthSdk`, `FirebaseGateway`, `DocumentStore`, `KeyValueStore`).
   Vérifié par `check_architecture.dart` (test : `architecture_rules_test.dart`).

Dépendances : `domain` ← `data`, `domain` ← `presentation`. Le domaine ne dépend de rien.

## Arbre de dossiers

```
app/
├── lib/
│   ├── main.dart                      # configureDependencies() + runApp
│   ├── app/                           # couche app
│   │   ├── app.dart                   # MaterialApp.router + l10n
│   │   ├── router.dart                # GoRouter (AppRoutes)
│   │   ├── record_sheet.dart          # showRecordSheet : feuille basse de saisie depuis le guide
│   │   ├── record_screens.dart        # buildRecordSetup / buildRecordSession : câblage unique (route et feuille)
│   │   ├── sheet_export.dart          # RunPlanExportSource : déroulé (run_sheet) -> entrées de l'export PDF (lot 14)
│   │   ├── platform/                  # plein écran, mise à jour, sortie PDF (web / natif par import conditionnel)
│   │   ├── firebase_options.dart      # généré par `flutterfire configure` (Android, iOS et web) (chemin fixé dans app/firebase.json)
│   │   ├── firebase_environment.dart  # FirebaseEnvironment : production / émulateur (--dart-define=FIREBASE_EMULATOR), release refuse l'émulateur
│   │   ├── firebase_gateway.dart      # port du SDK (initialize, useEmulators) ; firebase_startup.dart : FirebaseStartup (start / ready)
│   │   ├── di/firebase_module.dart    # câblage prod de Firebase ; platform/firebase_sdk_gateway.dart : SDK réel
│   │   ├── auth/                      # lot FB2 : AuthCubit (unknown / signedOut / noClub / ready / indisponible), AuthState, authRedirect (pure), AuthRefresh, RunningSessionsClubSwitchGuard
│   │   ├── session_startup.dart       # SessionStartup : ce que l'AuthCubit attend (FirebaseStartup en production, double en mémoire en test)
│   │   ├── di/auth_module.dart        # SessionScope exposé par CurrentUser et ActiveClubScope ; KeyValueStore de production
│   │   ├── platform/firebase_auth_sdk.dart  # AuthSdk ; avec platform/firebase_sdk_gateway.dart, les deux seuls importeurs de firebase_auth (règle 9) ; platform/shared_preferences_key_value_store.dart : seul importeur de shared_preferences
│   │   └── di/injection.dart          # @InjectableInit → injection.config.dart (généré)
│   ├── pages/                         # une page par parcours, Bloc fourni par le routeur
│   │   ├── home/  session_planner/
│   │   ├── students/  student_form/   # (a) liste des élèves, ajout / édition
│   │   ├── student_sheet/  student_showcase/  group_overview/   # (b) fiche en parcours, vue élève, vue de groupe
│   │   ├── record_setup/  record_session/   # (c) saisie des résultats d'une séance
│   │   ├── suggested_session/  exercise_sheet/   # (d) séance suggérée, fiche source
│   │   ├── assessment/                # (e) bilan de maturité, changement de public manuel
│   │   ├── backup/                    # (f) export / import JSON
│   │   ├── season_closure/  season_archive/   # lot 11 : assistant de clôture, « Saisons passées »
│   │   ├── export_sheet/              # lot 14 : export PDF d'une séance (hors du cadre de navigation)
│   │   └── settings/                  # réglages du club (sous « Plus »)
│   ├── widgets/session_list/  widgets/roster_picker/   # blocs réutilisables entre pages
│   ├── features/plan_session/
│   │   ├── domain/                    # PlanSession, ListSessions, InvalidSessionTitle
│   │   └── presentation/{bloc,ui}/    # SessionPlannerBloc, PlanSessionForm
│   ├── features/manage_students/          # EnrollStudent, GetClubOverview, ListEnrollmentGroups ; StudentsBloc, ClubList
│   ├── features/manage_groups/            # CreateGroup, RenameGroup, DeleteGroup, MoveStudent (lot 11a) ; ManageGroupsCubit, MoveStudentCubit
│   ├── features/close_season/             # PrepareSeasonClosure, CloseSeason, buildArchive, proposeClosure (lot 11b/c) ; SeasonClosureBloc
│   ├── features/track_seasons/            # ListSeasonArchives ; SeasonArchivesCubit, SeasonArchiveView (« Saisons passées »)
│   ├── features/record_results/           # OpenSession, RecordAttempt (R1, R2, R4) ; RecordResultsBloc
│   ├── features/suggest_session/          # planSession (R6), selectRecall (R5), suggestSheet (lot 8) ; SessionPlanView, ExerciseDiagramView
│   ├── features/place_student/            # MarkBlockAcquired, RevokeBlockAcquired ; PlacementBloc, boîte de dialogue
│   ├── features/assess_maturity/          # RecordAssessment (aide, jamais un déclencheur)
│   ├── features/change_audience/          # ChangeAudience (R7, manuel, confirmation)
│   ├── features/track_progress/           # ExerciseCurve, BlockProgress (R3), StudentSheet, SheetHeader, PathRow ; PathList, SheetHeaderCard
│   ├── features/acknowledge_alert/        # AcknowledgeAlert, RestoreAlert (ADR 0013) ; AcknowledgementBloc
│   ├── features/student_showcase/         # GetStudentShowcase (prénom et parcours seulement) ; ShowcaseCubit, ShowcaseView
│   ├── features/track_group/              # groupAttendance, groupFailureAlerts, GetGroupOverview ; GroupHeatMap, GroupAlertsCard
│   ├── entities/session/
│   │   ├── domain/                    # Session (freezed), SessionRepository
│   │   └── data/in_memory_session_repository.dart
│   ├── entities/exercise_catalog/     # ExerciseCatalogue, TrainingBlock, ExerciseSpec
│   │   ├── domain/                    # + port CatalogueRepository
│   │   └── data/                      # parseur YAML (package yaml) + asset
│   ├── entities/exercise_diagram/     # ExerciseDiagram, DiagramLibrary, DiagramKey
│   │   ├── domain/                    # modèle freezed (Dart pur) + port DiagramRepository
│   │   ├── data/                      # parseur YAML strict + repository asset
│   │   └── presentation/              # table_diagram_mapper : domaine -> TableDiagramSpec
│   ├── entities/exercise_result/      # ExerciseAttempt, ExerciseResult dérivé, StudentProgress,
│   │                                  # BlockAcquisition + port AcquisitionRepository (ADR 0008)
│   ├── entities/student/              # Student, AudienceChange (historique)
│   ├── entities/season/               # Season (closedOn, isOpenOn), SeasonArchive, nextSeasonAfter, SeasonArchiveRepository
│   ├── entities/group/  entities/session_record/   # group : chooseGroup, normalizedGroupName, Group.rename
│   ├── entities/maturity_assessment/  # chacun : domain/ (+ port) et data/ (en mémoire + drift)
│   ├── entities/settings/             # ClubSettings, SettingsRepository (drift + en mémoire)
│   ├── entities/account/              # lot FB2 : Account, AuthRepository, AuthFailure(Code), SessionScope ; data = AuthSdk (frontière du SDK), FirebaseAuthRepository, InMemoryAuthRepository
│   ├── entities/membership/           # lots FB2, FB3 : ClubMembership (rôle, groupes, fiches), Member, MemberRepository, MembershipsSource (+ isAdmin), ActiveClubMemory ; data = StoreMembershipsSource, StoreMemberRepository
│   ├── entities/club/                 # lot FB3 : Club, ClubRepository ; data = StoreClubRepository
│   ├── entities/invitation/           # lot FB3 : Invitation, InvitationPolicy, InvitationRepository, InvitationLog, IssuedInvitations, InvitationCodeSource ; data = StoreInvitationRepository, KeyValueInvitationLog
│   ├── features/manage_club/          # lot FB3 : « Mon club » : membres, retrait, renommage, invitations (créer, lister, révoquer) ; ClubCubit, InviteCubit
│   ├── features/administration/       # lot FB3 : « Administration » : clubs, directeurs invités ; AdministrationCubit
│   ├── features/sign_in/              # lot FB2 : SignIn, ResendVerification, RequestPasswordReset, RegisterWithInvitation, PendingInvitations ; lot FB3 : AcceptInvitation, JoinCubit, JoinForm ; SignInCubit, RegisterCubit, ForgotPasswordCubit, formulaires, AccountSection
│   ├── features/select_club/          # lot FB2 : resolveActiveClub, ChooseClub ; ClubChoiceList
│   ├── entities/run_progress/         # RunProgress, RunProgressKey, RunProgressRepository (drift + en mémoire) :
│   │                                  # séances guidées en cours, lot 10b (ADR 0020)
│   ├── features/export_sheet/         # lot 14 (ADR 0021) : domaine = scène d'impression, mise en page des deux
│   │                                  # documents, schémas, gabarit fédéral, cas d'usage ; data = PdfPrintRenderer (seul
│   │                                  # importeur de `pdf`) ; presentation = ExportSheetCubit, ExportView, aperçu
│   ├── features/manage_settings/      # LoadSettings, SaveSettings, ResetSettings, SettingsField ;
│   │                                  # SettingsBloc, SettingsForm
│   ├── features/backup_data/          # ExportBackup, ImportBackup, BackupCodec, BackupMarkerRepository,
│   │                                  # CheckBackupReminder, RecordBackupDone ; BackupBloc, BackupView,
│   │                                  # BackupReminderCubit, BackupReminderBanner
│   └── shared/
│       ├── lib/                       # noyau Dart pur : Audience, identifiants typés,
│       │                              # ExerciseRef, SuccessRate, RulesConfig,
│       │                              # Failure/Result, IdGenerator, Clock,
│       │                              # UnitOfWork, StorageStatus, PdfFiles (sortie PDF),
│       │                              # CurrentUser, ActiveClubScope (ClubId, Role), ClubSwitchGuard, KeyValueStore (FB2) ;
│       │                              # FB3 : InvitationCode, Capability/RolePolicy, ClubSession, field_limits
│       ├── persistence/               # base drift (SQLite) : tables, AppDatabase,
│       │                              # ouverture natif/web, unité de travail ; FB3 : DocumentStore (port Firestore),
│       │                              # InMemoryDocumentStore, guardStore ; FB4 : ClubPaths, ClubStore (club résolu à chaque appel),
│       │                              # DocumentValues (lecture des champs), DocumentStore.query (égalité, AllEqual, array-contains-any),
│       │                              # FB4c : OwnerResolver / StudentData (groupe et saison dénormalisés, lecture par rôle),
│       │                              # SendStatus / SendTracker (envoi des lots, FB5)
│       ├── ui/                        # design system (voir design-system.md)
│       │   ├── theme/                 # ColorScheme, extensions billes/statuts, typo, AppTheme
│       │   └── *.dart                 # ScoreIndicator, BallChip, SectionCard, PageHeader…
│       └── l10n/{app_fr,app_en}.arb   # + generated/ (non versionné)
├── test/
│   ├── bdd/*.feature                  # comportement (+ *_test.dart générés, non versionnés)
│   ├── step/*.dart                    # définitions de steps (versionnées)
│   ├── unit/…                         # miroir de lib/ (TDD)
│   └── tool/                          # tests du vérificateur d'architecture
├── assets/fonts/                      # Exo 2 + licence OFL
├── assets/catalogue/                  # copie du catalogue (scripts/sync_catalogue.sh)
├── assets/diagrammes/                 # copie des pages à table (scripts/sync_diagrammes.sh)
├── assets/fiches/                     # copie des séances du catalogue (scripts/sync_fiches.sh)
├── tool/                              # check_architecture.dart (+ architecture/)
├── l10n.yaml  build.yaml  analysis_options.yaml
└── android/ ios/ web/ macos/ windows/  # macOS et Windows hors production (Linux supprimé, ADR 0024)
widgetbook/                            # projet séparé : catalogue du design system
├── lib/main.dart                      # @App + addons
├── lib/use_cases/                     # @UseCase par composant et par page
└── lib/main.directories.g.dart        # généré (non versionné)
```

## Interface du suivi

- **Routage** : `go_router` (`app/router.dart`, `AppRoutes`). Chaque élève a une
  adresse (`/students/:studentId`, `…/edit`, `…/assessment`), de même qu'une séance
  saisie (`/record/:sessionId`) et une fiche source (`/exercises/:blockId/:number`).
  Un groupe a sa grille (`/students/groups/:groupId`, dans le cadre de
  navigation) et un élève sa vue « à montrer » (`/students/:studentId/show`,
  hors du cadre : lot U9).
  `/record` est l'**historique** des séances saisies (ADR 0006) ; l'ouverture
  d'une nouvelle saisie est `/record/new` (déclarée avant `/record/:sessionId`,
  comme `/students/new`), avec les paramètres des liens profonds (`main`,
  `recall`, `exercise`, `from`, `group`, `absent`, `date`). La barre de
  navigation (smartphone) devient un rail dès 720 px
  (`shared/ui/app_navigation.dart`).
- **Historique et correction des passages** (ADR 0006) : `ListRecordedSessions`
  (`features/record_results/domain`) résume chaque séance ; `CorrectAttempt`
  remplace un passage en place (`AttemptRepository.add` est idempotent) et
  `DeleteAttempt` le supprime puis renumérote les `passIndex` restants du même
  élève, exercice et séance dans une `UnitOfWork`. Aucune méthode ajoutée aux
  ports. L'assiduité (`attendanceOf`, `features/track_progress/domain`) est une
  fonction pure sur les séances et les appartenances aux groupes ; sa valeur
  `Attendance` vit dans `shared/lib` et sert aussi à la grille du groupe.
- **Positionnement initial** (ADR 0008) : `BlockAcquisition` (marqueur élève ×
  bloc, date, source `placement`), `AcquisitionSource` et le port
  `AcquisitionRepository` vivent dans `entities/exercise_result` (même slice que
  `StudentProgress.derive`, qui les lit : la règle FSD interdit l'import entre
  slices d'une même couche). `StudentProgress.validated` = exercices validés
  par passages ∪ `acquiredExercises` ; un passage daté du jour du
  positionnement ou après reprend la main sur son exercice seulement. Les
  six appelants de `derive` (`GetStudentSheet`, `GetStudentReport`,
  `GetClubOverview`, `SuggestSession`, `SuggestRecall`, `RecordAttempt`)
  lisent `AcquisitionRepository.forStudent`. `features/place_student` porte
  `MarkBlockAcquired`, `RevokeBlockAcquired` et `PlacementBloc` ; la page
  `student_sheet` compose le bloc et transmet des callbacks à `PathList` (menu
  ⋮ de chaque technique ; `BlockProgressList` a disparu avec le lot U9).
- **Pages** (couche `pages`) : composent des Bloc fournis par le routeur et des vues
  de `features/*/presentation/ui` ; elles ne contiennent aucune règle métier ni
  `StatefulWidget` : la sélection du groupe et des présents vit dans
  `RosterSelectionCubit` (`widgets/roster_picker/presentation`, état freezed),
  la date de la séance dans `SessionDateCubit`
  (`features/record_results/presentation/bloc`), tous deux fournis par le
  routeur. Le filtre des groupes proposables est `ClubOverview.eligibleGroups`
  (domaine).
- **Adresses invalides** : le routeur a un `errorBuilder` (`NotFoundPage`,
  localisé) et la route `/exercises/:blockId/:number` valide ses paramètres
  (`ExerciseRef.tryParse`) ; un lien profond mal formé affiche cette page au
  lieu de planter.
- **Courbe de performance** : `shared/ui/progress_chart.dart` (`CustomPainter`, sans
  dépendance). Un essai réussi est un disque plein, manqué un anneau creux ; la
  fiche élève ajoute la liste textuelle des essais (alternative accessible).
- **Accessibilité** : cibles >= 48 dp (`AppSpacing.minTouchTarget`), `Semantics` sur
  les dessins, état toujours doublé d'une icône et d'un libellé (jamais la couleur
  seule).
- **Changement de public** : action explicite et manuelle (`AudienceChangeCard` avec
  confirmation) ; le bilan de maturité n'est qu'une aide affichée prudemment.
- **Sauvegarde** : `BackupFiles` (port, `features/backup_data/domain`) ; implémentation
  `file_picker` (téléchargement web / partage fichier) et variante en mémoire pour
  les tests. Un avertissement est affiché si `StorageStatus` signale une
  persistance volatile.
- **Rappel de sauvegarde** (lot U6) : `BackupMarkerRepository` (port,
  `features/backup_data/domain`, implémentations drift et en mémoire) retient
  la date et le nombre de passages à chaque export enregistré (table
  `backup_exports`, schéma v6 ; donnée locale, absente du fichier de
  sauvegarde). `BackupReminder.evaluate` (règle pure, seuil `staleAfterDays` issu de
  `RulesConfig.backupReminderDays` (défaut 30 jours), horloge injectée via `CheckBackupReminder`) ; `RecordBackupDone`
  est appelé par `BackupBloc` quand le fichier est enregistré ;
  `BackupReminderCubit` + `BackupReminderBanner`, composés dans `HomePage`
  par le routeur.
- **Réglages** (lot 9, ADR 0012) : `ClubSettings` (`entities/settings`, 5
  entiers, aucune validation propre) ; `RulesConfig` n'est plus un singleton
  mais une fabrique qui lit `RulesStore.current` (`shared/lib`, initialisé au
  lancement par `app/di/rules_module.dart`) ; `SaveSettings` valide par
  `RulesConfig`, écrit (table `app_settings`, schéma v7), puis remplace la
  valeur courante ; depuis FB4c, `ReloadRules` (feature `manage_settings`, appelé par `AuthCubit`) la recharge **à l'activation et à la bascule de club**
  (les réglages sont un document par club) et la remet aux valeurs par défaut à la déconnexion. `SettingsField` (domaine de la feature) porte les bornes et
  le pas d'écran, sous-ensemble des bornes de `RulesConfig`. Les réglages
  voyagent dans la sauvegarde JSON (format 2, clé `data.settings` facultative).
  `BackupReminder.evaluate` reçoit `staleAfterDays` (`backupReminderDays`).

## Saisons et groupes (lot 11, ADR 0019)

- **Saison close** : `Season.closedOn` (nul = ouverte). `Season.isOpenOn(date)`
  (non close **et** dans la période) remplace `contains` aux **sept sites**
  « saison en cours » (`GetClubOverview`, `ListGroupAlerts`,
  `ListPlannableGroups`, `ListJourneyGroups`, `EnrollStudent`) et « travail
  nouveau » (`OpenSession`, `PlanSession` : refus `seasonClosed`) ;
  `BackupRules` garde `contains` (données historiques), sauf pour les séances
  planifiées d'une saison close, bornées par le seul début. `currentGroups`
  prend `closedSeasons` : le repli « aucune saison en cours » n'y puise jamais.
- **Groupes** : plusieurs par (saison, public) ; l'unicité du nom
  (`normalizedGroupName`) est une règle de cas d'usage, sans contrainte SQL.
  `chooseGroup` (pure) choisit le groupe d'une inscription / d'un changement de
  public (`groupChoiceRequired` s'il y en a plusieurs sans demande). `MoveStudent`
  clôt l'appartenance la veille de la date d'effet et ouvre l'autre ce jour-là ;
  rien n'est copié.
- **Clôture** (`features/close_season`) : `CloseSeason` est **une seule unité de
  travail** : archive calculée **avant** l'effacement (`buildArchive`, pure),
  enregistrée, saison close, élèves choisis effacés (mêmes dépôts que
  `EraseStudent`, parité testée), saison suivante préparée (`nextSeasonAfter`,
  réutilisée si elle existe), séances planifiées supprimées. L'archive
  (`SeasonArchive`, `entities/season`) ne porte **aucun** identifiant d'élève,
  groupe ni date de séance ; une ligne par exercice n'existe qu'à partir de
  `minCohortForFigures` = 3 élèves distincts (règle, pas réglage).
  `proposeClosure` (pure) propose, l'animateur décide.
- **Persistance** : version courante **schéma v11, sauvegarde v5**. Historique, du plus ancien au plus récent :
  schéma v9 (`seasons.closed_on`, `season_archive_audiences`, `season_archive_exercises`, migration additive
  `from8To9`) ; schéma v10 (`run_progress_entries`, migration additive `from9To10`, voir « Séance guidée en
  cours » ci-dessous) ; schéma v11 (colonne `tags_json` sur `session_records` et `run_progress_entries`,
  ADR 0023). Sauvegarde v4 : `seasons[].closedOn` facultatif, `seasonArchives` obligatoire en v4 et refusée
  en v1 à v3, inchangée par le schéma v10. Sauvegarde v5 : `sessionRecords[].tags` obligatoire en v5, refusée
  en v1 à v4. Importer un fichier qui donne une saison pour ouverte la rouvre et supprime son archive.
- **Séance guidée en cours** (lot 10b, [ADR 0020](adr/0020-seance-en-cours-persistee-locale-hors-sauvegarde.md)) :
  `RunSheetCubit` garde l'étape, les compteurs d'initiation, la grille « acquis », le score A / B, le minuteur
  (écrit toutes les 10 s, à la pause et au changement de phase) et l'identifiant de la saisie ouverte, via
  `RunProgressKeeper` (`features/run_sheet/domain`, seul point de contact avec `RunProgressRepository`). Écritures
  sérialisées, jamais bloquantes. Au démarrage, `RunSheetSessions.restore()` (appelé par `main`, sans bloquer)
  relit les lignes (péremption 7 jours, 4 plus récentes) ; chaque cubit relit lui-même sa ligne au premier
  `load()` et la **rapproche de la séance du catalogue** (`reconcileRunProgress`, pure). Aucun identifiant d'élève
  dans la table ; **hors sauvegarde** (transitoire, propre à l'appareil). Effacement d'un élève (donc clôture de
  saison) : `EraseStudent` efface par lien (groupes dont il a été membre, leurs séances planifiées, saisies où il
  était présent), liens calculés avant l'effacement des présences et appartenances ; parité vérifiée par
  `erasure_parity_test`.
- **Pages qui composent** : `pages/season_closure` assemble l'assistant
  (`close_season`) et l'export (`backup_data`) ; `pages/students` assemble les
  menus de groupe (`manage_groups`) ; `pages/student_sheet` « Changer de
  groupe » ; `home` reçoit la carte `ClosableSeasonSection` par la couche app.
- **Routes** : `/seasons` (dans le cadre, destination « Plus ») et
  `/seasons/:seasonId/close` (**hors** du cadre : un geste de navigation ne quitte
  pas l'assistant à mi-chemin).
- **Effectif d'une saison pas encore commencée** : `GetClubOverview` et
  `GetGroupOverview` lisent l'effectif au premier jour de la saison (les élèves
  reconduits ne sont pas « sans groupe » pendant l'été).

## Noyau partagé (`shared/lib`) et slices d'entités

Une entité ne peut pas importer une autre entité (règle 2). Les petits objets
valeur que plusieurs entités partagent vivent donc dans `shared/lib` (Dart pur) :
`Audience`, identifiants typés (`StudentId`…), `ExerciseRef`, `SuccessRate`,
`RulesConfig` (tous les seuils sont de la configuration, jamais des constantes de
règle), `Failure` scellée et `Result`. Les règles qui croisent plusieurs entités
(catalogue + passages) prennent des types du noyau en paramètre
(`ExerciseCatalogue.rates`, `StudentProgress.derive`) ou vivent dans une feature.

Taux de réussite `[S]` : un passage n'est réussi que si son total couvre au
moins les tentatives de la fiche (`SuccessRate.acceptsTotal`) ; au-delà, la
comparaison de proportions est exacte `[Prop]`. La saisie refuse un total
inférieur (`totalBelowSheet`) et le compteur d'interface ne descend pas sous
les tentatives de la fiche : « 1 sur 1 » ne valide donc jamais un exercice.

Un invariant est vérifié dans le constructeur privé `X._()` d'une classe `freezed`
(non `const`) : toute instance, y compris issue de `copyWith`, est valide. Les
cas d'usage retournent `Result<T>` (`runGuarded` convertit les `Failure` levées).

## Schémas d'exercices (`entities/exercise_diagram`)

Les transcriptions YAML de `docs/knowledge/03-exercices/diagrammes/`
(`FORMAT.md`) sont la source unique ; `scripts/sync_diagrammes.sh` en copie les
pages à table (`kind` `exercise`, `game`, `initiation`) vers
`app/assets/diagrammes/<dossier>/pNN.yaml`, `--check` (lecture seule, dans
`check.sh --fast`) refusant toute différence ou tout fichier en trop.

- **Domaine** (Dart pur) : `ExerciseDiagram` (freezed ; métadonnées de la fiche
  et `DiagramTable`), `DiagramKey` (famille, titre de fiche, numéro d'exercice),
  `DiagramLibrary` (`find(key)` renvoie une liste : la source répète la fiche
  « Le rejet naturel », donc deux schémas par exercice ; vide quand la source
  n'en a pas), port `DiagramRepository`. Les types de table (`TableBall`,
  `TablePocket`...) sont propres au domaine : `domain` n'importe pas `shared/ui`.
- **Data** : `parseDiagramPage` (refuse tout champ non représenté,
  `InvalidDiagramPage`) et `AssetDiagramRepository` (toute erreur de lecture :
  page mal formée, E/S, manifeste -> `invalidDiagram`).
- **Présentation** : `tableDiagramSpecOf` convertit un `ExerciseDiagram` en
  `TableDiagramSpec` du design system (`contactFractionOf` pour la quantité de
  bille) ; `shared/ui` ne voit jamais le domaine.
- **Branché sur la fiche d'un exercice** : `GetExerciseSheet`
  (`features/suggest_session/domain`) charge la `DiagramLibrary` et range dans
  `ExerciseSheet.diagrams` les schémas de la clé `DiagramKey.training(...)`.
  Des schémas illisibles (`invalidDiagram`, ce code seulement ; toute autre
  violation remonte à `runGuarded`) ne font pas échouer la fiche :
  `diagramsUnreadable` remplace le lecteur par un message. `ExerciseDiagramView`
  (`features/suggest_session/presentation/ui`) affiche, par schéma, le
  `TableDiagramPlayer` (largeur max. 720 dp, la page défile), la légende du PDF,
  la quantité de bille en texte localisé (`ExerciseDiagram.contacts`, calculé
  par le domaine : celle des tirs, sans doublon ; le chevalet n'est écrit que par
  la carte de la fiche, d'après le catalogue) ; « Schéma i sur n » quand la source répète la fiche ; un message
  quand l'exercice n'a pas de schéma. `ExerciseSheetPage` l'affiche via
  `ExerciseSheetView` ; la séance suggérée ne montre pas de schéma (elle renvoie
  à la fiche). Route et DI inchangées (`/exercises/:blockId/:number`,
  `ExerciseSheetBloc`).
- **Correspondance avec le catalogue** : par les données, `TrainingBlock.title`
  = `sheet` et `ExerciseSpec.ref.number` = `exercise`
  (`DiagramKey.training(...)`) ; aucune table écrite à la main. Vérifiée par
  `test/contract/catalogue_diagrammes_test.dart` (70 exercices, tous illustrés : 64 par les pages
  transcrites `[S]`, 6 par `diagrammes/proposition/` `[Prop]` pour les blocs
  proposés `posture` et `bille-fantome`, dont `Provenance.prop` porte la
  mention ; décompte tenu à jour dans `FORMAT.md` § 1.2).
- **Non représenté** : l'encart `inset` (quantité de bille, point du procédé)
  n'est pas encore lu ; ses valeurs `tip_point` dépassent `TipPoint`.

## Catalogue de séances (consultation)

ADR 0004, lot L4. Lecture seule de bout en bout :

- `entities/session_sheet` : modèle immuable, port `SessionSheetRepository`
  (`getAll`, `getById`) et les règles pures qui ne dépendent que de la séance,
  écrites une seule fois et appelées par les deux features :
  `reviewReasonsOf` / `needsReview` / `gameNeedsReview` (motifs « à valider »),
  `groupByTechnique` (ordre d'enseignement, rang, nombre de parties),
  `partCountOf` et `diagramIdsOf` (schémas à lire) ; `presentation/` porte
  `IllustrationMapper` et `SheetIllustrationView` (composent `shared/ui`, sans
  importer `exercise_catalog` ni `exercise_diagram`).
- Placement de la résolution (ADR 0004, décision 13 révisée) : la lecture des
  schémas et des taux se fait **dans les features** (`GetSheet`,
  `ResolveRunPlan`), par leurs dépendances descendantes vers `entities` ; il
  n'y a pas de slot en `pages`. Seule la notation est composée en `pages`/`app`
  par callbacks.
- `features/browse_sheets` : `ListSheets` (groupes par technique, rang et
  nombre de parties), `GetSheet` (séance, séance précédente, taux du
  catalogue d'entraînement par `ExerciseRef`, schémas par identifiant,
  minutage de chaque public calculé depuis `RulesConfig.shapes`),
  `SheetCatalogueBloc` (filtres « à valider » et « jeux à valider », état
  d'écran), `SheetDetailBloc` (public affiché, relance après échec). Des schémas illisibles ne font pas échouer la lecture.
- `pages/sheet_catalogue`, `pages/sheet_detail` : composition par callbacks ;
  un identifiant inconnu ou mal formé mène à `NotFoundPage`.
- Routes `/catalogue` (`?group=<id>` : groupe dont le parcours est montré) et
  `/catalogue/:sheetId` (`?audience=children|adults`, `?from=planner|today`
  origine du retour, `?group=<id>` groupe du catalogue à restaurer), destination
  « Séances » du shell. La suggestion par groupe `/session` n'a plus de bouton
  dans le catalogue : son onglet « Suggestion » est l'unique accès (lot U8).
- **Catalogue en mode « Préparer » (lot U8, [plan](catalogue-preparer-plan.md))** :
  - `SheetRow` / `sheetRowOf` (`features/browse_sheets/domain`) : nom évocateur,
    technique, partie, motifs qui comptent (le « n » du badge unique) et motifs
    seulement signalés (théorie, règle de lien) ; `reviewPointCount`
    (`entities/session_sheet`) garantit `n > 0 ⇔ needsReview`, donc badge et
    filtre « À valider » ne divergent pas.
  - Parcours d'un groupe (`features/suggest_session`) : `givenSheets` (règle
    « faite », ADR 0009, extraite de `suggestSheet` et partagée), `GetGroupJourney`
    (`SuggestNextSheet` tel quel pour la séance recommandée), `ListJourneyGroups`
    (groupes des saisons en cours, règle du planificateur) et `GroupJourneyCubit`
    (le dernier choix gagne ; un échec ne donne aucun marqueur). `JourneyMark` et
    `GroupChoice` (`shared/lib`) sont les seuls types échangés : `browse_sheets`
    n'importe jamais `suggest_session` ; c'est `pages/sheet_catalogue` qui relie
    `SheetCatalogueBloc` et `GroupJourneyCubit`.
  - `SheetOrigin { catalogue, planner, today }` (`app/router.dart`) : origine du
    détail dans l'adresse (`from`), jamais un état en mémoire ; toute valeur
    inconnue retombe sur `catalogue`. `AppRoutes.catalogueFor(group)` restaure
    le groupe au retour. Le détail reçoit seulement `backLabel` (la page ne
    connaît pas les routes).
- Lien séance planifiée ↔ séance du catalogue (lot L5) : `Session.sheetId`
  (`SheetId?`, `shared/lib`) ; `features/plan_session` lit le catalogue par
  `ListSheetOptions` (`SheetOption` et `sheetOptionsOf` vivent en
  `entities/session_sheet/domain` : identifiant, technique, rang, partie, pour
  la planification, la saisie et l'historique) et `PlanSession(title, date,
  audience, sheetId?, groupId?)`. Le choix vit dans `SessionPlannerBloc`
  (`selectedSheet`) ; le formulaire préremplit le titre, qui reste modifiable.
  `/planner?sheet=<id>&audience=` présélectionne une séance (bouton
  « Planifier cette séance » du détail). La liste (`widgets/session_list`)
  ouvre le détail de la séance liée, ou affiche « séance indisponible » et
  « Choisir une séance » (vers `/catalogue`). La sauvegarde écrit `sheetId` ;
  `BackupRules` refuse un identifiant inconnu (`backupUnknownSheet`), sans
  décodeur ancien (V1 non livrée).
- **Séance planifiée datée et par groupe, saisie liée** ([ADR 0007](adr/0007-lien-seance-planifiee-saisie-catalogue.md)) :
  `Session(id, title, date, audience, groupId?, sheetId?)` ; `PlanSession`
  prend le public du groupe et refuse une date hors de sa saison
  (`seasonOutsidePeriod`) ou un groupe inconnu (`unknownGroup`) ;
  `ListPlannableGroups` (groupes de la saison en cours, règle `currentGroups`
  de `entities/group/domain`, partagée avec `GetClubOverview`) ;
  `ListSessions` rend des `PlannedSessionSummary` (séance, groupe, saisie du
  même groupe, même jour, même séance du catalogue : règle pure `recordFor`
  de `entities/session_record/domain/record_matching.dart`, partagée avec
  `OpenOrResumeSession`, ADR 0016) triés par date. Le lien planifiée ↔ saisie
  est **dérivé** (aucune clé étrangère).
  `SessionRecord.sheetId` note la séance du catalogue ; `ResolveSheetBlocks`
  (`features/record_results/domain`) en dérive la notion principale et le
  rappel de résultats (`resultsRecallBlock`, en `entities/session_sheet/domain`)
  pour `OpenSession` et `OpenOrResumeSession` quand ils ne sont pas donnés ;
  une séance inconnue est refusée (`unknownSheet`). `SessionOverview.sheet` et
  `RecordedSessionSummary.sheet` libellent la séance notée dans la saisie et
  l'historique. Routes : `/record/new?group=&date=&sheet=` depuis la liste des
  séances planifiées (`AppRoutes.recordFromPlan`) ; le guide lancé depuis une
  séance planifiée (`RunPlan.planned`) pré-remplit groupe et date
  (`RunSheetState.recordDefaults` : le choix d'une saisie précédente prime sur
  la séance planifiée ; le routeur ne fait que le lire). Les blocs dérivés d'une séance
  (`SheetBlocks.resolve`) ne remplacent jamais des blocs donnés. Schéma drift
  v4 (ADR 0001).
- Garde-fous : `test/contract/session_sheets_render_test.dart` rend les 28
  séances (fr et en, deux publics, texte à 200 % sur téléphone, tablette en
  paysage) et chaque illustration, sans erreur de rendu.

## Séance guidée (lancement)

ADR 0004, lot L6. La séance est suivie, montrée aux élèves et notée sans
jamais modifier le contenu du catalogue :

- `features/run_sheet` : `ResolveRunPlan(sheetId, audience?, sessionId?)` donne
  le déroulé (`RunPlan` : accueil ou rappel, théorie, initiation, exercices,
  créneau d'exercice de rappel, jeu, bilan ; minutes calculées ; taux du catalogue d'entraînement ; schémas
  par identifiant ; bloc du rappel de **résultats**, calculé par
  `resultsRecallBlock` : le bloc de la plus récente séance précédente dont le
  bloc diffère du bloc principal). Sans public demandé, celui de la séance
  planifiée, sinon les enfants.
- Créneau d'exercice de rappel ([ADR 0011](adr/0011-creneau-exercice-de-rappel.md)) :
  - Le modèle : `SessionSheet.recallSlot` (`{weight, passes}`, présent si et
    seulement si la séance a une `previous`, donc à partir de la 2e) ;
    `RunStepKind.recallExercise` est la **dernière** étape de la phase
    d'entraînement, après les exercices de la séance, et ses minutes viennent
    du budget de cette phase.
  - Le choix : `chooseRecallExercise` est une fonction **pure**
    (`features/run_sheet/domain/recall_exercise.dart`) qui rend un
    `RecallExercise` (séance d'origine, exercice, élèves en attente, élèves
    suivis). Elle retient l'exercice des séances précédentes que le plus
    d'élèves n'ont pas validé (à égalité le plus récent ; sans élève ou tout
    validé, le dernier exercice de la séance précédente).
  - Les données : `LoadValidatedExercises` (`@injectable`, domaine de
    `features/run_sheet`) lit les élèves suivis (membres du groupe de la
    séance planifiée à sa date, sinon élèves du public) et leurs exercices
    validés ou acquis au positionnement (ADR 0008) ; `ResolveRunPlan` les
    passe à `chooseRecallExercise`.
  - Le plan : `RunPlan.recallExercise` porte le choix ; `recallSpec` (la
    spécification d'entraînement : consigne, mise en place, taux, lue dans le
    catalogue d'entraînement) et `recallBlockTitle` (titre du bloc d'origine)
    permettent d'afficher l'étape comme un exercice ordinaire ; le schéma est
    celui de l'exercice choisi, donc montrable en présentation.
  - La saisie : « Noter les résultats » depuis le créneau ouvre la saisie sur
    l'exercice choisi, dont le bloc devient le bloc de rappel de la saisie s'il
    diffère du bloc principal. Cette dérivation est aujourd'hui écrite dans
    `pages/sheet_guide` ; la revue l'a relevée comme règle métier à
    déplacer vers `features/run_sheet/domain` (roadmap, audit des séances).
    Rien n'est enregistré sans saisie.
- `RunSheetCubit` porte l'étape courante, les compteurs d'initiation, la grille
  « acquis », le score du jeu et le minuteur indicatif (source `RunTicker`
  injectable, jamais bloquant). Tout est local et jamais enregistré ; toutes
  les étapes sont atteignables librement (relecture sans élèves). Les cubits
  vivent dans `RunSheetSessions` (singleton, clé `RunKey` = séance, public
  demandé, séance planifiée, groupe), au-dessus du routeur : les compteurs
  survivent à la sortie du guide (changement d'étape, lien profond).
  « Terminer la séance » (après confirmation) réinitialise l'état puis
  **libère** le cubit (`release`) ; au plus `maxRunning` séances restent en
  cours, la moins récemment utilisée étant évincée ; le minuteur s'arrête quand
  le guide quitte l'écran. `RunSheetCubit.syncFromRoute(step)` est la seule
  synchronisation avec l'adresse : sans `step` et avec de la progression, il
  propose « Reprendre à l'étape n » ou « Recommencer ».
- Barre d'actions épinglée (sommaire, montrer, minuteur, terminer) hors du
  défilement quand la hauteur le permet ; « Montrer » est inactif sur une étape
  sans illustration dessinée (un simple `pdf_ref` n'est pas présentable).
  « Retour » et « Terminer » reviennent au planificateur quand le guide a été
  lancé depuis une séance planifiée (`?session=`), sinon à la séance du
  catalogue.
- Saisie depuis le guide (lot U5) : le groupe, la date et les absents de la
  première saisie sont retenus (`RunSheetState.recordChoice`, écrit par
  `RunSheetSessions.recordChosen`) et réutilisés pour les exercices suivants.
  « Noter les résultats » appelle `showRecordSheet` (couche `app`,
  `app/record_sheet.dart`) : une feuille basse qui réutilise `RecordSetupPage`
  puis `RecordSessionPage`, sur l'exercice courant. Le guide n'est pas démonté
  et reste à la même étape ; fermer la feuille ne perd rien (tout est
  persisté à « Saisir »). `_RecordSheet` est un `StatefulWidget` qui garde
  l'étape (ouverture ou saisie) : état de présentation, permis dans la
  couche `app`. Le câblage des écrans (blocs, groupe, présents, date) est écrit
  une seule fois dans `app/record_screens.dart` (`buildRecordSetup`,
  `buildRecordSession`), partagé par les routes `/record/new`,
  `/record/:sessionId` et la feuille. Le retour système ferme la feuille et
  ramène le guide à la même étape (scénario BDD). Il n'existe plus de
  constructeur d'adresse `recordFromGuide` : seules les routes subsistent
  (liens profonds, ADR 0007).
- `RunPresentationCubit` : mode présentation, qui résout son propre déroulé
  (route de premier niveau, hors du shell) et parcourt les étapes qui ont
  quelque chose à montrer ; son étape est locale à la présentation.
- Pages `sheet_guide` et `sheet_presentation` : composition par callbacks.
  `features/run_sheet` n'importe ni `record_results` ni `suggest_session` : la
  saisie des résultats est composée par la couche `app`.
- Routes : `/catalogue/:sheetId/guide?audience=&session=&step=&group=&from=&via=&mode=`
  et `/catalogue/:sheetId/presentation?` (mêmes paramètres), **toutes deux de premier
  niveau, hors du shell** (lot U4, [ADR 0015](adr/0015-guide-mener-route-modes-origine.md)) :
  `group` = groupe pour lequel on prépare ou on mène (catalogue, séance suggérée,
  ADR 0009), `step` à partir de 0 ramené dans la plage, public absent = celui de la
  séance planifiée, `from` = origine directe du lancement (`planner`, `today`,
  `suggestion`), `via` = origine du détail quand le guide en vient, `mode` =
  `lead` ou `review` (écrit seulement s'il diffère du défaut de la clé :
  Mener pour une séance planifiée, Relecture sinon). Le retour est décidé par
  la fonction pure `guideBackTarget` (couche `app`). Le guide est lancé depuis le
  détail (qui transmet `via` et `group`), la liste des séances planifiées
  (`from=planner`), Aujourd'hui (`from=today`, « Lancer » et « Reprendre ») ou
  la séance suggérée (`from=suggestion`, `mode=lead`, groupe transmis).
- `features/run_sheet` (U4) : `RunMode` et `runTimerRemaining` sont du domaine pur
  (`run_mode.dart`, `run_timer.dart`, aucune horloge : les secondes viennent du
  `RunTicker` injecté) ; `RunSheetState` porte `mode`, `timerRemaining` et
  `timerTone`. Le seuil d'une minute et la fonction pure `timerToneFor` ont une
  source unique, `shared/lib/timer_tone.dart` (`TimerTone`), que `TimerChip` et le
  guide partagent. La vue (`run_sheet_view.dart` et ses `part`) compose uniquement des
  composants de `shared/ui` (`StepAppBar`, `PhaseTimeline`, `TimerChip`) ; la page
  `sheet_guide` ne connaît ni `AppRoutes` ni `SheetOrigin` (callbacks `onBack`,
  `onStepChanged`, etc.).
- Notation : `/record/new?main=<bloc>&recall=<bloc de rappel>&exercise=<n>&sheet=<séance>&from=<adresse>`
  puis `/record/:sessionId?exercise=<n>&from=…` ne servent plus qu'aux liens
  profonds (ADR 0007) et à la saisie hors guide. `from` n'est suivi que
  s'il est intérieur à l'application et sous `/catalogue/` ; sinon il est
  ignoré. `RecordResultsEvent.started` présélectionne l'exercice du bloc
  principal. `SessionOverview` porte `history` (passages de tous les élèves
  présents), `progress` (`StudentProgress.derive` de chaque élève, acquis au
  positionnement compris, ADR 0008), `passedCount(élève, exercice)` (le
  « n sur 5 » de la grille, lu dans `progress`) et `exerciseName`,
  lu dans `SheetOption.exerciseTitles` (titres des exercices de la séance du
  catalogue).
- Garde-fous : `test/contract/session_sheets_guide_test.dart` rend le guide et
  la présentation sur les 28 séances, à chaque étape (fr et en, deux publics,
  texte à 200 % sur téléphone, tablette en paysage).

## Suggestion ↔ catalogue (lot 8)

ADR 0009, [plan](suggestion-catalogue-plan.md). La séance suggérée propose la
séance du catalogue correspondant à sa notion, sans migration :

- `features/suggest_session/domain` : `suggestSheet` (fonction pure : bloc
  principal, exercice de tête, séances, saisies du groupe, passages par saisie,
  jour courant, exercices validés par tout le groupe) renvoie une
  `SheetSuggestion?` (`option`, `kind` : `coversHead` / `nextPending` /
  `repeat`, `exerciseNumbers`, `headCovered`, `head`, `lastGivenOn`), nulle
  pour un bloc sans séance du catalogue (`quantites-de-billes`,
  `trajectoires-blanche`). `SuggestSession` lit `SessionSheetRepository` et
  `Clock`, calcule les passages par saisie et pose `SessionPlan.sheet` ; si la
  séance ne contient pas l'exercice de tête, `plan.exercises` devient ceux de la
  séance non validés par tout le groupe (durée et phases inchangées).
  « Faite » = saisie du groupe avec `sheetId` et au moins un passage, datée
  d'aujourd'hui ou avant.
- `SessionPlanView` : carte « Séance du catalogue » (titre, partie, raison,
  note sur l'exercice de tête) et actions Ouvrir, Lancer, Planifier ; sans
  séance, message de repli et Planifier sans séance. `SuggestedSessionPage`
  relaie `onOpenSheet`, `onLaunch`, `onPlan` avec le public du plan et le
  groupe ; `onRecord` reçoit aussi la séance proposée.
- Routes : `AppRoutes.recordFromSuggestion(group, main, recall?, sheet?)`,
  `AppRoutes.guide(group:)` et `AppRoutes.presentation(group:)` (`RunKey.group`,
  repris par `_runKey` / `_guideKey`), `AppRoutes.plan(SheetId?)`. La saisie
  ouverte depuis le guide reçoit le groupe (`recordDefaults.group` puis
  `key.group`).
- Garde-fou : `test/contract/session_sheets_block_coverage_test.dart` (chaque
  exercice d'un bloc à séances est dans exactement une séance).

## Design system et Widgetbook

**État d'animation éphémère dans `shared/ui`.** L'interdiction du
`StatefulWidget` vaut pour `pages` (état de page : Bloc). Un composant de
`shared/ui` peut garder dans son `State` ce qui dépend de Flutter et ne survit
pas au widget : un `AnimationController` et son ticker, la lecture/pause en
cours, le choix de vitesse local. Dès qu'un état doit survivre au composant ou
être piloté de l'extérieur (vitesse mémorisée, lecture lancée par une page), il
sort dans un Cubit à état freezed fourni par l'appelant. `TableDiagramPlayer`
est le seul cas à ce jour : sa vitesse et sa lecture sont locales et
volontairement non persistées.

`shared/ui` contient le design system : thème (`theme/`) et composants
indépendants du métier. La règle « vers le bas uniquement » les protège : un
composant ne peut importer aucune entité ; il définit ses propres enums et la
page fait le mapping. Le catalogue Widgetbook est un **projet séparé**
(`widgetbook/`, dépendance `path: ../app`) qui n'est jamais importé par `app/`.
Détails : [design-system.md](design-system.md).

## Injection de dépendances

- `@injectable` (cas d'usage, Bloc) et `@LazySingleton(as: Port)` (repository,
  générateur d'id) sur les classes ; get_it les enregistre via
  `await configureDependencies()` (asynchrone : la base SQLite est ouverte et
  migrée au lancement, `@preResolve`).
- **Environnements** : `prod` (par défaut ; repositories drift, UUID) et `test`
  (`configureDependencies(environment: Environment.test)` : dépôts en mémoire,
  identifiants séquentiels). Une implémentation s'annote
  `env: [Environment.prod]` ou `[Environment.test]` ; le câblage de la base est
  dans `app/di/persistence_module.dart`.
- Le code **généré** (`injection.config.dart`, `*.freezed.dart`, `*.g.dart`,
  `l10n/generated/`, `test/bdd/*_test.dart`) n'est **pas versionné** : il est produit
  par `scripts/generate.sh` (`flutter gen-l10n` puis `dart run build_runner build`).
- Les widgets ne résolvent jamais get_it eux-mêmes : seule la couche `app`
  (routeur) fournit les Bloc via `BlocProvider(create: (_) => getIt<…>())`.

## Persistance

Les ports de repository sont dans `domain` ; leurs implémentations vivent dans
`data` (en mémoire pour les tests et le BDD, drift pour l'application).
`shared/persistence` ne dépend d'aucune entité : chaque entité y prend la base
(`AppDatabase`) et écrit ses mappers. Les écritures multiples passent par le
port `UnitOfWork` (transaction SQLite ; journal d'annulation en mémoire). Les
ports portent aussi l'effacement physique d'un élève (`erase`, `eraseStudent`). Décision et schéma : ADR 0001.

## Accueil « Aujourd'hui » et bilan de séance (lot U7)

Plan et décisions : [aujourdhui-plan.md](aujourdhui-plan.md). Aucune migration,
aucune dépendance, pas d'ADR.

- **Slices** : `entities/exercise_result/domain/watch_list.dart` (règle
  d'alerte partagée, `watchedStudents`) ; `features/plan_session`
  (`GetUpcomingSessions`, `upcomingOf`, `UpcomingSessionsCubit`,
  `PlanNextSessionCubit`) ; `features/track_progress` (`ListWatchedStudents`,
  `weekSummary`, `GetWeekSummary`, leurs cubits) ; `features/run_sheet`
  (`RunSheetSessions.snapshot()` en lecture seule, `RunningSessionsCubit` avec
  `abandon`, `RunRecordChoice.recordId`) ; `features/suggest_session`
  (`SuggestNextSheet`, `NextSheetCubit`, règle du lot 8 inchangée) ; nouvelle
  slice `features/review_session` (`GetSessionReview`, `reviewSession` pure,
  `nextSameWeekday`, `SessionReviewBloc`, `SessionReviewView`).
- **Pages qui composent** : `pages/home` (quatre cubits indépendants + le
  `banner` du routeur) et `pages/session_review` (bilan + séance suivante +
  planification). Aucune feature n'importe une autre : la jointure « groupe
  de la séance en cours » et « déjà planifiée » est faite par la page.
- **Route** : `/record/:sessionId/review` (`AppRoutes.review`), dans le shell,
  sous « Résultats » ; adresse déclarée avant `/record/:sessionId`. « Terminer »
  (`SheetGuidePage.onFinish`, `ValueChanged<SessionId?>`) lit
  `recordChoice?.recordId` **avant** `finish()` ; le routeur mène au bilan puis
  libère le guide. Sans saisie ouverte : retour inchangé.
- **Données du bilan** : relues des dépôts (le bilan survit à un rechargement) ;
  les titres de blocs viennent de `ExerciseCatalogue.blockLabels` (titre et
  statut `[Prop]`), portés par `WatchList` et `SessionReview`.
- **Limite connue** : le registre des séances guidées (`RunSheetSessions`) est
  en mémoire ; « En cours » ne survit pas à un rechargement (plan U-5).

## Export PDF (lot 14)

Plan et décisions : [export-pdf-plan.md](export-pdf-plan.md),
[ADR 0021](adr/0021-export-pdf-feuille-animateur-et-fiche-resultats.md). Aucune
migration, sauvegarde inchangée (v4), aucun asset ajouté (Exo 2 est déjà précachée).

- **Scène d'impression** (`features/export_sheet/domain/print_scene.dart`) : pages en
  points (origine en haut à gauche), éléments `PrintText` (ligne déjà coupée, ligne
  de base `y`), `PrintLine`, `PrintPolyline`, `PrintRect`, `PrintCircle`,
  `PrintPolygon`, niveaux de gris seulement. Deux interprètes la rendent : le PDF
  (`PdfPrintRenderer`, `data`) et l'aperçu (`PrintScenePainter`, `presentation`).
- **Mise en page en domaine pur**, mesure du texte par le port `TextMeasure` (fournie
  par la fonte embarquée : la coupure et le dessin utilisent les mêmes métriques) :
  `layoutAnimatorSheet` (déroulé, sections, pagination par blocs insécables),
  `layoutResultsSheets` + `ResultsTemplate` (gabarit mesuré sur le PDF fédéral),
  `drawDiagram` (schéma de table en vectoriel), `wrapText`, `printable` (θ par le mot
  de la langue, « thêta » en français ; caractère absent de la fonte refusé).
- **Entrées sans élève** : `SheetPrintInput` n'a aucun champ nominatif ; les
  prénoms d'un groupe n'entrent que par `ResultsSheetsRequest.groupId`, lu par
  `ExportResultsSheets` (membres du jour, tri sans accents) **quand l'animateur l'a
  demandé** ; `ResolveRunPlan(withRecallExercise: false)` évite de lire les élèves
  pour le créneau de rappel.
- **Jonction** (couche `app`, une feature n'en importe pas une autre) :
  `RunPlanExportSource` met en forme le `RunPlan` de `run_sheet` en
  `SheetPrintInput` / `ResultsPlan` (port `ExportSource` de la feature).
- **Sortie** : port `PdfFiles` (`shared/lib`) : `FilePickerPdfFiles` (téléchargement
  sur le web, boîte d'enregistrement ailleurs), impression directe sur le web par
  une iframe cachée (`pdf_files_web.dart`, `dart:js_interop`, URL d'objet locale).
- **Écran** : route `/catalogue/:sheetId/export?audience=` hors du cadre ;
  `ExportSheetCubit` (le dernier choix gagne), `ExportView`, `PrintPreviewView`.
  Entrées : bouton du détail d'une séance, menu ⋮ du guide.

## Fiche en parcours, vue élève et vue de groupe (lot U9)

Plan : [fiche-eleve-plan.md](fiche-eleve-plan.md) ; décisions : [ADR
0013](adr/0013-acquittement-des-alertes.md) (acquittement, schéma v8, sauvegarde
v3) et [ADR 0014](adr/0014-fiche-en-parcours-vue-eleve-et-vue-de-groupe.md)
(écrans).

- **Slices** : `entities/exercise_result` (cases `exerciseCells`,
  `techniqueSummary`, `AlertAcknowledgement` et `AcknowledgementRepository`,
  `blockFailedStudents`, `StudentProgress.derive(acknowledgements:)`) ;
  `features/track_progress` (`SheetHeader`, `PathRow`, `StudentSheet.path` et
  `.header`, `SheetHeaderCard`, `PathList`, `ExerciseCurveSheet`) ;
  `features/acknowledge_alert` (`AcknowledgeAlert`, `RestoreAlert`,
  `AcknowledgementBloc`) ; `features/student_showcase` (`StudentShowcase`,
  `GetStudentShowcase`, `ShowcaseCubit`, `ShowcaseView`) ; `features/track_group`
  (`groupAttendance`, `groupFailureAlerts`, `GetGroupOverview`,
  `ListGroupAlerts`, `GroupOverviewCubit`, `GroupAlertsCubit`, les cinq
  sections `Group*`). Aucune de ces features n'en importe une autre : elles
  partagent leurs règles par `entities` et leurs composants par `shared/ui`
  (`PathCell`, `HeatCell`, `CellGrid`, qui ne connaissent aucune entité).
- **Pages qui composent** : `pages/student_sheet` (fiche, rappel, effacement,
  positionnement **et acquittement** : `MultiBlocListener`, `SnackBar`,
  rechargement de la fiche), `pages/student_showcase` (`PopScope` : le retour
  système ramène à la fiche), `pages/group_overview`, et les pages `students`
  (callback `onOpenGroup`) et `home` (`GroupAlertsCubit`, carte
  `GroupAlertsCard`).
- **Routes** : `/students/groups/:groupId` (`AppRoutes.studentGroup`) **dans**
  le cadre de navigation (destination « Élèves » active), déclarée avant
  `/students/:studentId` ; `/students/:studentId/show` (`AppRoutes.showcase`)
  **hors** du cadre, à côté de la présentation plein écran : ni barre ni rail.
  La route de la fiche fournit en plus `AcknowledgementBloc`, celle de l'accueil
  `GroupAlertsCubit`.
- **Garantie de confidentialité de la vue élève** : le modèle `StudentShowcase`
  n'a aucun champ sensible et `GetStudentShowcase` ne lit ni les bilans, ni les
  séances, ni les acquittements ; un test interdit à la slice d'importer les
  slices correspondantes.
- **Règles de calcul** : toute la dérivation (`derive`, cases, technique, alerte
  de groupe) reste en Dart pur avec l'horloge en paramètre (`asOf`) ; les
  cubits lisent `Clock.today()`.

## Authentification et session (lot FB2, ADR 0024)

Détail : [auth-plan.md](auth-plan.md). L'essentiel de l'architecture :

- **Aucune route sans compte.** `AuthCubit` (couche `app`, un seul exemplaire `@lazySingleton`) pilote `authRedirect`
  (fonction pure) par `GoRouter.refreshListenable`. Il vit dans `app/` parce qu'il compose des slices qui ne peuvent
  pas s'importer : `entities/account` (comptes), `entities/membership` (clubs) et `features/select_club` (club actif).
- **Ports minuscules** dans `shared/lib`, sans dépendance au SDK : `CurrentUser` et `ActiveClubScope` (`ClubId`, `Role`)
  sont lus **à chaque appel** par les dépôts (jamais figés dans un singleton), comme `RulesStore` (ADR 0012). Un seul
  porteur, `SessionScope` (`entities/account/domain`), écrit uniquement par `AuthCubit` et exposé sous les deux ports
  par `di/auth_module.dart`. Le club actif reconstruit l'interface (`KeyedSubtree(clubId)` autour du routeur) ;
  `ClubSwitchGuard` (port) interdit la bascule pendant une séance guidée, `RunningSessionsClubSwitchGuard` l'implémente.
- **Le SDK reste à la frontière.** `firebase_auth` n'est importé que sous `app/platform/` (`firebase_auth_sdk.dart` et `firebase_sdk_gateway.dart`, règle 9)
  (`AuthSdk`, port de `entities/account/data`) ; `FirebaseAuthRepository` traduit les codes du SDK en `AuthFailureCode`
  génériques. `SessionStartup` (`FirebaseStartup` en production) est ce que l'`AuthCubit` attend avant de lire la session.
- **Stockage local** : `KeyValueStore` (port) ; `shared_preferences` n'est importé que par
  `app/platform/shared_preferences_key_value_store.dart`. Clés par compte (`active_club.<uid>`, `pending_invitation.<uid>`).
- **Environnement `test`** : dépôt d'authentification, appartenances, stockage et démarrage **en mémoire**
  (`InMemoryAuthRepository`, `InMemoryDocumentStore` derrière `StoreMembershipsSource`, `InMemoryKeyValueStore`, `InMemorySessionStartup`) ;
  `FirebaseStartup` n'y est toujours pas câblé. Production : `FirebaseAuthRepository`, `StoreMembershipsSource` sur `FirestoreDocumentStore` (FB3).

## Clubs, rôles et invitations (lot FB3, ADR 0024)

Détail et tableaux : [clubs-roles-plan.md](clubs-roles-plan.md). L'essentiel de l'architecture :

- **Dépôts Firestore par club (FB4)** : `ClubStore` (`shared/persistence`) relit `ActiveClubScope` **à chaque appel** et refuse l'accès sans club ; `ClubPaths` nomme tous les chemins
  (aucun dépôt n'en compose un). Chaque dépôt a son codec (`*_document.dart`, dates en ISO 8601, champs de la liste blanche des règles) et choisit sa requête selon le rôle (les règles
  n'autorisent pas la même à tous). `DataBackendModule` (`app/di`) aiguille drift (défaut) ou Firestore par `--dart-define=DATA_BACKEND` pour **tous** les dépôts de données (réglages, élèves, groupes, saisons, archives, séances planifiées, saisies, **passages, blocs acquis, bilans, acquittements** ; seuls `run_progress` et le marqueur de sauvegarde restent locaux). **Le défaut reste drift jusqu'à FB7** : la bascule de production est un lot dédié après FB7 (décision de l'utilisateur, 2026-10-18). Avec Firestore, l'unité de travail est `CompositeUnitOfWork` : le lot Firestore est validé localement **sans attendre le serveur** et son envoi est suivi par `SendStatus` (FB5). Un passage est **un document** (`clubs/{c}/attempts/{id}`, ajout seul) dont le rang se dérive (`createdAt` du serveur, puis `recordedAt` de l'appareil, puis identifiant). Voir [repositories-firestore-plan.md](repositories-firestore-plan.md).
- **Flux temps réel (FB5b)** : `DocumentStore` offre `watchDocument`, `watchCollection` et `watchQuery` (un état complet à chaque changement, métadonnées
  `fromCache` / `hasPendingWrites`, erreur = `StoreFailure` qui ferme **ce** flux, annulation sans fuite) ; `ClubStore.watch…` les lie à la portée (club, rôle,
  périmètre) et `watchSources` combine les lectures d'un rôle (`combineLatest`). Les dépôts ajoutent des `watch…` **ciblés** à leurs ports (les `Future`
  restent) : mémoire (`ObservedMap`) et drift (`tableUpdates`) via `watchRead`, Firestore via `guardStoreStream` (traduction en `ServiceFailure`). Les écrans lisent
  par `LiveReload` : les cas d'usage `Watch…` (`changesOf`) ne disent que **quand relire** ; le calcul reste celui des cas d'usage existants. Les blocs sont créés par
  les pages et fermés avec elles. Un changement de club, de rôle ou de périmètre ne referme **pas** les blocs des pages ouvertes (`ClubScoped` est posé dans `MaterialApp.builder`, le `Navigator` de go_router a une clé globale) ; les défenses sont : (1) `ClubStore` ferme les flux épinglés à l'**écriture de la portée** (`ActiveClubScope.changes`, `permissionDenied` `scope-changed`, écoute relâchée sans attendre un événement), (2) `LiveReload` rouvre l'écoute après l'erreur, (3) `ClubScoped` (clé triée club + rôle + groupes + fiches) reconstruit ce qui est sous lui. `ClubStore.commit` ne bloque plus l'interface
  hors ligne (délai de grâce puis `SendTracker`). Règle de conflit : ADR 0024, notes FB5b.
- **Un port minuscule pour Firestore** : `DocumentStore` (`shared/persistence`) ne connaît ni collection typée ni SDK : `get`, `list`, requête de groupe de collections sur un
  champ, **lot atomique** (`SetOp`, `UpdateOp`, `DeleteOp`, date du serveur `serverTimestamp`). `app/platform/firestore_document_store.dart` l'implémente sur
  `cloud_firestore` (règle 9) en deux étages : `FirestoreSdkAccess` (quatre appels directs au SDK) et `FirestoreDocumentStore` (traduction des valeurs et des échecs, testée sur
  un accès scripté). Tous les dépôts de FB3 (`StoreClubRepository`, `StoreMemberRepository`, `StoreMembershipsSource`, `StoreInvitationRepository`, `StoreStudentDirectory`) ne
  dépendent que du port : **les mêmes classes servent la production et les scénarios BDD** (sur `InMemoryDocumentStore`, qui n'émule aucune règle).
- **Les règles sont le garde de fond, l'interface ne propose que ce qu'elles acceptent.** La table des droits est unique (`Capability`, `RolePolicy` dans `shared/lib`) ; les cas
  d'usage la lisent (`requireClubSession`, `requireAdmin`) et refusent d'eux-mêmes (`InvariantCode.actionNotAllowed`), les menus la lisent, et le routeur l'applique aux adresses
  (`roleRedirect`, appelé par `authRedirect` : fonction pure).
- **Qui agit** : `ActiveClubScope` porte désormais le périmètre du `member` (groupes, fiches liées) et `CurrentUser.isAdmin` ; `SessionScope` reste le seul porteur, écrit
  uniquement par `AuthCubit`. Un cas d'usage lit la portée **à chaque appel** (`ClubSession`), jamais figée.
- **`AuthCubit` en FB3** : il lit aussi `isAdmin` et le code gardé à l'inscription ; un compte sans club et avec code est envoyé sur `/join/<code>` ; un administrateur sans club
  atteint « Administration ». Il efface à la déconnexion le club retenu **et** le journal local des invitations.
- **Écrans d'un élève ou d'un parent** : `AppShell` n'a que « Mes enfants » (« Ma progression ») et « Plus » ; la fiche en parcours (`/students/<id>/show`) reste hors du cadre.
- **Invitation par lot** : `InvitationRepository.accept` lit l'invitation (états distincts : introuvable, expirée, utilisée), puis écrit **un seul lot** (`member` + consommation) ;
  le serveur le re-vérifie (`getAfter`). Voir le plan pour les formes, durées et la révocation.

## États et modèles

- Modèles et états immuables : `freezed` (`@freezed abstract class …` ou `sealed class`
  pour les événements). Le getter dérivé (ex. `Session.duration`) vit dans le modèle.
- Un Bloc par écran/feature, événements nommés au passé (`sessionSubmitted`).

## Ajouter une feature (pas à pas)

1. **Spécifier le comportement** : écrire/ajuster un `.feature` dans `app/test/bdd/`
   (voir [testing.md](testing.md)). Il doit échouer (rouge).
2. **Entité** (si nouveau concept) : `entities/<nom>/domain/` (modèle freezed, port
   `…Repository`), puis `entities/<nom>/data/` (implémentation `@LazySingleton(as: …)`).
3. **Cas d'usage** : `features/<verbe_nom>/domain/` (`@injectable`, TDD avec mocktail).
4. **Bloc** : `features/<verbe_nom>/presentation/bloc/` (freezed events/state, TDD avec bloc_test).
5. **UI** : `features/<verbe_nom>/presentation/ui/`, textes via `AppLocalizations`
   (clés fr **et** en, voir [i18n.md](i18n.md)).
6. **Composition** : widget partagé dans `widgets/`, écran dans `pages/<nom>/presentation/`,
   route dans `app/router.dart`.
7. `scripts/generate.sh` puis `scripts/check.sh --full` ; tout doit être vert.

Un dossier de slice ne se crée pas « par précaution » : n'ajouter une couche que
si une règle de ce document l'impose.
