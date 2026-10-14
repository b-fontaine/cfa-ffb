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
| `pages` | Écrans routables, composent widgets et features | `pages/home`, `pages/session_planner` |
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

Dépendances : `domain` ← `data`, `domain` ← `presentation`. Le domaine ne dépend de rien.

## Arbre de dossiers

```
app/
├── lib/
│   ├── main.dart                      # configureDependencies() + runApp
│   ├── app/                           # couche app
│   │   ├── app.dart                   # MaterialApp.router + l10n
│   │   ├── router.dart                # GoRouter (AppRoutes)
│   │   ├── firebase_options.dart      # généré par `flutterfire configure` (chemin fixé dans app/firebase.json)
│   │   └── di/injection.dart          # @InjectableInit → injection.config.dart (généré)
│   ├── pages/                         # une page par parcours, Bloc fourni par le routeur
│   │   ├── home/  session_planner/
│   │   ├── students/  student_form/   # (a) liste des élèves, ajout / édition
│   │   ├── student_sheet/             # (b) fiche : progression, courbes, rappel
│   │   ├── record_setup/  record_session/   # (c) saisie des résultats d'une séance
│   │   ├── suggested_session/  exercise_sheet/   # (d) séance suggérée, fiche source
│   │   ├── assessment/                # (e) bilan de maturité, changement de public manuel
│   │   └── backup/                    # (f) export / import JSON
│   ├── widgets/session_list/  widgets/roster_picker/   # blocs réutilisables entre pages
│   ├── features/plan_session/
│   │   ├── domain/                    # PlanSession, ListSessions, InvalidSessionTitle
│   │   └── presentation/{bloc,ui}/    # SessionPlannerBloc, PlanSessionForm
│   ├── features/manage_students/          # EnrollStudent, GetClubOverview ; StudentsBloc, ClubList
│   ├── features/record_results/           # OpenSession, RecordAttempt (R1, R2, R4) ; RecordResultsBloc
│   ├── features/suggest_session/          # planSession (R6), selectRecall (R5) ; SessionPlanView, ExerciseDiagramView
│   ├── features/place_student/            # MarkBlockAcquired, RevokeBlockAcquired ; PlacementBloc, boîte de dialogue
│   ├── features/assess_maturity/          # RecordAssessment (aide, jamais un déclencheur)
│   ├── features/change_audience/          # ChangeAudience (R7, manuel, confirmation)
│   ├── features/track_progress/           # ExerciseCurve, BlockProgress (R3), StudentSheet ; courbes
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
│   ├── entities/season/  entities/group/  entities/session_record/
│   ├── entities/maturity_assessment/  # chacun : domain/ (+ port) et data/ (en mémoire + drift)
│   ├── features/backup_data/          # ExportBackup, ImportBackup, BackupCodec ; BackupBloc, BackupView
│   └── shared/
│       ├── lib/                       # noyau Dart pur : Audience, identifiants typés,
│       │                              # ExerciseRef, SuccessRate, RulesConfig,
│       │                              # Failure/Result, IdGenerator, Clock,
│       │                              # UnitOfWork, StorageStatus
│       ├── persistence/               # base drift (SQLite) : tables, AppDatabase,
│       │                              # ouverture natif/web, unité de travail
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
└── android/ ios/ web/ linux/ macos/ windows/
widgetbook/                            # projet séparé : catalogue du design system
├── lib/main.dart                      # @App + addons
├── lib/use_cases/                     # @UseCase par composant et par page
└── lib/main.directories.g.dart        # généré (non versionné)
```

## Interface du suivi

- **Routage** : `go_router` (`app/router.dart`, `AppRoutes`). Chaque élève a une
  adresse (`/students/:studentId`, `…/edit`, `…/assessment`), de même qu'une séance
  saisie (`/record/:sessionId`) et une fiche source (`/exercises/:blockId/:number`).
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
  fonction pure sur les séances et les appartenances aux groupes.
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
  `student_sheet` compose le bloc et transmet des callbacks à
  `BlockProgressList`.
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
  `test/contract/catalogue_diagrammes_test.dart` (72 exercices, tous illustrés : 64 par
  les pages transcrites `[S]`, 8 par `diagrammes/proposition/` `[Prop]` pour les blocs
  proposés `posture` et `bille-fantome`, dont `Provenance.prop` porte la mention).
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
- Routes `/catalogue` et `/catalogue/:sheetId` (`?audience=children|adults`),
  destination 3 du shell (« Séances ») ; la suggestion par groupe `/session`
  reste accessible par un bouton en tête du catalogue.
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
  même groupe le même jour, `DateOnly.isSameDayAs` de `shared/lib`) triés par
  date. Le lien planifiée ↔ saisie est **dérivé** (aucune clé étrangère).
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
  la séance planifiée ; le routeur ne fait que le lire, puis
  `AppRoutes.recordFromGuide(sheet:)`). Les blocs dérivés d'une séance
  (`SheetBlocks.resolve`) ne remplacent jamais des blocs donnés. Schéma drift
  v4 (ADR 0001).
- Garde-fous : `test/contract/session_sheets_render_test.dart` rend les 29
  séances (fr et en, deux publics, texte à 200 % sur téléphone, tablette en
  paysage) et chaque illustration, sans erreur de rendu.

## Séance guidée (lancement)

ADR 0004, lot L6. La séance est suivie, montrée aux élèves et notée sans
jamais modifier le contenu du catalogue :

- `features/run_sheet` : `ResolveRunPlan(sheetId, audience?, sessionId?)` donne
  le déroulé (`RunPlan` : accueil ou rappel, théorie, initiation, exercices,
  jeu, bilan ; minutes calculées ; taux du catalogue d'entraînement ; schémas
  par identifiant ; bloc du rappel de **résultats**, calculé par
  `resultsRecallBlock` : le bloc de la plus récente séance précédente dont le
  bloc diffère du bloc principal). Sans public demandé, celui de la séance
  planifiée, sinon les enfants.
- `RunSheetCubit` porte l'étape courante, les compteurs d'initiation, la grille
  « acquis », le score du jeu et le minuteur indicatif (source `RunTicker`
  injectable, jamais bloquant). Tout est local et jamais enregistré ; toutes
  les étapes sont atteignables librement (relecture sans élèves). Les cubits
  vivent dans `RunSheetSessions` (singleton, clé = séance, public demandé,
  séance planifiée), au-dessus du routeur : `context.go` retire la page du
  guide, mais les compteurs survivent à un aller-retour par la saisie.
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
- Saisie depuis le guide : le groupe, la date et les absents de la première
  saisie sont retenus (`RunSheetState.recordChoice`) et passés en
  `/record?group=&absent=&date=` pour les exercices suivants.
- `RunPresentationCubit` : mode présentation, qui résout son propre déroulé
  (route de premier niveau, hors du shell) et parcourt les étapes qui ont
  quelque chose à montrer ; son étape est locale à la présentation.
- Pages `sheet_guide` et `sheet_presentation` : composition par callbacks.
  `features/run_sheet` n'importe ni `record_results` ni `suggest_session` : la
  saisie des résultats est composée par la couche `app`.
- Routes : `/catalogue/:sheetId/guide?audience=&session=&step=` (`step` à
  partir de 0, ramené dans la plage ; le public absent est celui de la séance
  planifiée) et `/catalogue/:sheetId/presentation?audience=&session=&step=`
  (hors du shell). Le guide est lancé depuis le détail d'une séance ou depuis la
  liste des séances planifiées.
- Notation : « Noter les résultats » ouvre `/record/new?main=<bloc>&recall=<bloc
  de rappel>&exercise=<n>&sheet=<séance>&from=<adresse du guide>` (le groupe
  et la date viennent du choix précédent ou de la séance planifiée ; sans eux,
  le groupe se choisit à la saisie), puis `/record/:sessionId?exercise=<n>&from=…`. `from` n'est
  suivi que s'il est intérieur à l'application et sous `/catalogue/` ; sinon il
  est ignoré. `RecordResultsEvent.started` présélectionne l'exercice du bloc
  principal ; le retour ramène au guide à la même étape.
- Garde-fous : `test/contract/session_sheets_guide_test.dart` rend le guide et
  la présentation sur les 29 séances, à chaque étape (fr et en, deux publics,
  texte à 200 % sur téléphone, tablette en paysage).

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
