# Positionnement initial / bloc acquis : plan

Statut : **conception** (lot 7 de la [roadmap](roadmap.md) ; décisions A1 à A5
de l'animateur du 2026-10-14, A5 précisée par deux arbitrages ; aucun code écrit). Décision :
[ADR 0008](adr/0008-positionnement-initial-bloc-acquis.md). Contexte :
application V1 non livrée, aucune compatibilité de données à préserver. Règles
de développement : `AGENTS.md`, skills `dev-feature`, `dev-bdd`, `dev-tdd` ;
`architecture.md`, `testing.md`, `quality-gates.md`, `design-system.md`,
`i18n.md`.

## 1. Constat et objectif

Sans passage, un élève est « 0 / 72 » et la suggestion repart de « posture »
(`ExerciseCatalogue.nextExercise`, `planSession`). Pour un élève non débutant
ou arrivé en cours de saison, le suivi ne tient pas. Objectif : l'animateur
déclare, depuis la fiche de l'élève, qu'un **bloc entier est acquis** ; le
suivi et la suggestion en tiennent compte, sans passage fictif, et le
marqueur se retire ou cède la place aux vrais passages.

## 2. Décisions (reprises de l'ADR 0008)

1. Action **sur la fiche élève**, par bloc : « Marquer le bloc acquis » /
   « Retirer l'acquis » (A1).
2. **État distinct stocké** `BlockAcquisition` (élève, bloc, date, source
   `placement`) ; jamais de passages fictifs (A2).
3. **Bloc entier**, 15 blocs éligibles dont les 2 blocs `[Prop]` (A3).
4. Compté dans **« n / 72 »** ; saute l'ordre de suggestion ; libellé distinct
   **« Acquis au positionnement »** ; ordre rebond puis rejet inchangé (A4).
5. **Réversible** ; un passage daté du **même jour que le positionnement ou
   après** (`dateOnly`, `>=`) reprend la main **sur son exercice seulement** ;
   le reste du bloc reste acquis, le marqueur restant stocké (A5).
6. Schéma drift **v5**, clé de sauvegarde `blockAcquisitions`, effacement
   physique avec l'élève.
7. Hors lot : grille de positionnement en lot (élèves × blocs), marquage par
   exercice, positionnement par groupe, mention des blocs sautés sur la séance
   suggérée (§ 9).

## 3. Modèle de domaine

### Entité `entities/block_acquisition/domain`

| Fichier | Contenu |
|---|---|
| `block_acquisition.dart` | `@freezed BlockAcquisition { AcquisitionId id, StudentId studentId, String blockId, DateTime date, AcquisitionSource source }` ; `date` est un `DateTime` normalisé par l'extension `.dateOnly` (`shared/lib/date_only.dart`) ; invariants du constructeur : `blockId` non vide → `invalidExerciseRef`, `date == date.dateOnly` → `invalidRange` ; l'existence du bloc dans le catalogue (`unknownBlock`) se vérifie dans le cas d'usage, pas dans l'entité |
| `acquisition_source.dart` | `enum AcquisitionSource { placement }` ; texte stocké = nom de l'énumération ; relu par `AcquisitionSource.values.byName` dans le dépôt drift (même patron que `Audience.values.byName`, une valeur inconnue en base lève `ArgumentError`, la base n'étant écrite que par l'application) ; à l'import, source inconnue → `backupInvalid` (§ 4) |
| `acquisition_repository.dart` | port `AcquisitionRepository` : `add(BlockAcquisition)` (id connu = remplacement), `forStudent(StudentId)` (du plus ancien au plus récent), `all()`, `delete(AcquisitionId)` (logique, sans effet si absent), `eraseStudent(StudentId)` (physique, y compris supprimés logiquement) |

`AcquisitionId` s'ajoute à `shared/lib/identifiers.dart`
(`extension type const AcquisitionId(String value)`, comme `AssessmentId`).

`entities/block_acquisition/data` : `drift_acquisition_repository.dart`,
`in_memory_acquisition_repository.dart` (journal partagé, `UnitOfWork`
compatible comme les autres) ; enregistrés dans `app/di`.

### Impact sur `StudentProgress` (`entities/exercise_result/domain`)

- `StudentProgress.derive(..., required List<BlockAcquisition> acquisitions)`.
  Les marqueurs sont filtrés sur `studentId`. Plusieurs marqueurs non supprimés
  pour un même bloc (données importées) : le plus récent gagne. Pour chaque
  marqueur dont le bloc existe dans `rates` (exercices du bloc : `rates.keys`
  filtrés par `blockId` ; bloc inconnu ignoré), un exercice est **acquis**
  si aucun passage de `attempts` sur **cet exercice** n'a une date
  `dateOnly` `>=` `acquisition.date` (même jour compris). Un passage plus
  ancien que le positionnement ne reprend pas la main.
- Nouveaux champs : `acquiredBlocks: Map<String, BlockAcquisition>` (blocs dont
  au moins un exercice reste acquis), `acquiredExercises: Set<ExerciseRef>`
  (exercices encore acquis) et `resumedExercises: Set<ExerciseRef>` (exercices
  d'un bloc marqué repris par des passages).
- `validated` = exercices validés par passages **∪** `acquiredExercises`.
  Aucun `ExerciseResult` n'est créé pour un exercice acquis.
- `activeAlerts` exclut les résultats dont l'exercice est dans
  `acquiredExercises` ; l'alerte d'un exercice repris redevient visible.
- `isAcquired(blockId)` (tous les exercices du bloc acquis), `acquiredOn(blockId)`
  et `resumedCount(blockId)` en accesseurs.

### Impact sur le suivi (`features/track_progress/domain`)

- `BlockStatus` gagne `acquiredAtPlacement` (après `mastered`).
- `BlockProgress.of(block, progress, sessionsSpent)` :
  - `progress.isAcquired(block.id)` (tous les exercices acquis) →
    `validatedCount = exerciseCount`, `status = acquiredAtPlacement`,
    `overdue = false` ;
  - bloc marqué mais partiellement repris → statut dérivé comme avant, avec
    `validatedCount` = exercices du bloc dans `progress.validated` (union des
    exercices validés par passages et des exercices acquis) ; « Acquis »
    (`mastered`) si l'union couvre le bloc ;
  - sinon dérivation inchangée.
  Nouveaux champs : `acquiredOn: DateTime?` (marqueur actif ou partiellement
  repris) et `resumedCount: int` (exercices repris, pour « N exercices repris
  par les passages saisis depuis »), lus dans `progress`.
- `StudentReport.derive` : `validatedCount = progress.validated.length` (donc
  « n / 72 » inclut les exercices acquis et ne baisse que des exercices repris) ;
  `activeAlerts` repris de `progress`. Plus de champ `supersededOn`.
- `StudentSheet` : `nextExercise` déjà dérivé de `progress.validated` ; aucune
  règle ajoutée.

### Impact sur la suggestion (`features/suggest_session/domain`)

- `planSession` ne change pas : `catalogue.nextExercise(validated:
  student.validated)` saute les blocs acquis par construction ; l'ordre
  d'enseignement du catalogue (`teachingOrder`, rebond puis rejet) est le seul
  critère, donc inchangé. Les voisins du même bloc (`neighbours`) ne sont
  calculés que dans le bloc principal suggéré, jamais dans un bloc acquis pour
  tous.
- `selectRecall` ne lit que `results` : un bloc acquis sans passage n'est
  jamais candidat au rappel ; un bloc partiellement repris l'est par ses
  exercices à passages, comme avant.
- `SuggestSession`, `SuggestRecall` : lisent `AcquisitionRepository.forStudent`
  pour chaque élève attendu (paramètre obligatoire de `derive`).
- Cas limite : tous les blocs acquis pour tous les élèves → `nothingToTeach`
  (comportement existant « niveau terminé »).

### Cas d'usage `features/place_student/domain`

| Cas d'usage | Règles |
|---|---|
| `MarkBlockAcquired(studentId, blockId, date, today)` | élève inconnu → `NotFound('student')` ; bloc hors catalogue → `unknownBlock` ; `date` après `today` → `dateInFuture` ; marqueur non supprimé existant pour (élève, bloc) → `blockAlreadyAcquired` ; sinon `add` et retourne le `BlockAcquisition` |
| `RevokeBlockAcquired(studentId, blockId)` | aucun marqueur non supprimé → `NotFound('acquisition')` ; sinon `delete(id)` (logique) |
| `ListStudentAcquisitions(studentId)` | lecture simple pour le bloc ; la fiche lit déjà tout via `GetStudentSheet` |

`GetStudentSheet`, `GetStudentReport`, `GetClubOverview`, `SuggestSession`,
`SuggestRecall` et `RecordAttempt` (les six appelants de
`StudentProgress.derive` ; `BackupRules` ne l'appelle pas, il le cite
seulement en commentaire) lisent `AcquisitionRepository` (un seul `forStudent`).
`MarkBlockAcquired` normalise `date` par `.dateOnly` avant de comparer à `today`.

`EraseStudent` reçoit `AcquisitionRepository` dans son constructeur (cinq dépôts
aujourd'hui, six ensuite), appelle `eraseStudent` dans son unité de travail ; son
test unitaire et son docstring (« passages, bilans, présences… ») sont mis à
jour.

### `RecordAttempt` : reprise par un passage

- `progress` est dérivé deux fois sur le même historique : sans, puis avec le
  nouveau passage. `resumedFromPlacement = exercice ∈ acquiredExercises(avant)
  ∧ exercice ∉ acquiredExercises(après)`.
- `justValidated = passed ∧ result.passedCount == passesRequired ∧
  exercice ∉ acquiredExercises(avant)` : on ne « fête » pas la validation d'un
  exercice déjà acquis.
- `RecordedAttempt` gagne `resumedFromPlacement: bool` ; la saisie affiche un
  message « Exercice acquis au positionnement : les passages reprennent la
  main sur cet exercice (n / 5) » (clé `placementResumedFeedback`).
- `nextExercise = catalogue.nextExercise(validated: progress.validated)` après
  le passage : l'exercice repris, redevenu à valider, peut redevenir le
  suivant ; le reste du bloc reste sauté.
- Un passage daté avant le positionnement n'est pas une reprise
  (`resumedFromPlacement` faux), le résultat est enregistré normalement.

### `InvariantCode` et messages

- `unknownBlock` **existe déjà** (`shared/lib/failure.dart`, utilisé par
  `open_session.dart`, mappé sur `failGeneric` dans
  `shared/ui/failure_message.dart`) : le cas d'usage le réutilise.
- Nouveaux codes : `blockAlreadyAcquired`, `backupUnknownBlock`.
- `failure_message.dart` est un `switch` exhaustif : les deux codes y sont
  mappés (`failBlockAlreadyAcquired`, `failBackupUnknownBlock`, § 7).

## 4. Persistance

### Schéma drift v5 (`shared/persistence`)

```dart
@DataClassName('BlockAcquisitionRow')
@TableIndex(name: 'acquisitions_by_student', columns: {#studentId})
class BlockAcquisitions extends Table with AuditColumns {
  TextColumn get studentId => text()();   // pas de FK : suppression logique
  TextColumn get blockId => text()();     // asset du catalogue, pas de FK
  TextColumn get date => text().map(const IsoDateTimeConverter())(); // jour normalisé
  TextColumn get source => text()();      // 'placement'
}
```

- `AppDatabase.currentSchemaVersion = 5`, table ajoutée à `@DriftDatabase`.
- `from4To5: (m, schema) => m.createTable(schema.blockAcquisitions)` ; fichiers
  générés par `dart run drift_dev make-migrations`
  (`drift_schemas/app_database/drift_schema_v5.json`, `app_database.steps.dart`) ;
  jamais édités à la main.
- `app/test/unit/shared/persistence/migration_test.dart` (existant) : base v4 avec élève et passage → v5 : table vide,
  données conservées, ajout puis lecture d'un marqueur.

### Sauvegarde JSON (`features/backup_data`)

- `BackupSnapshot.blockAcquisitions` (requis, sans valeur par défaut).
  Encodeur : clé `blockAcquisitions`, éléments `{id, studentId, blockId, date,
  source}` (`date` jour ISO). Décodeur : `_read.objects(data['blockAcquisitions'])`
  comme les autres listes ; clé **obligatoire** (`JsonReader.list(null)` lève
  `backupInvalid`), champ manquant ou type faux → `backupInvalid`. Aucune
  compatibilité avec un fichier antérieur ; `BackupCodec.currentVersion = 1`
  et `supportedVersions = {1}` inchangés.
- `BackupReferences` : `studentId` doit exister (`backupInconsistent`).
- `BackupRules` : `blockId` inconnu du catalogue → `backupUnknownBlock`
  (comme `backupUnknownSheet`) ; date future → `backupInvalid` ;
  source inconnue → `backupInvalid` ; date non normalisée au jour →
  `backupInvalid`.
- `BackupUniqueness` : au plus un marqueur par (élève, bloc) dans une
  sauvegarde (`backupInconsistent`).
- `ImportBackup` / `ExportBackup` : écriture et lecture via
  `AcquisitionRepository` dans la même unité de travail que le reste ;
  `ImportSummary` gagne `blockAcquisitions` (compte). Test de contrat
  (`app/test/contract/backup_contract.dart`) : aller-retour avec un marqueur.
- Effacement : `app/test/unit/shared/persistence/physical_erasure_test.dart`
  (existant) vérifie que les marqueurs de
  l'élève disparaissent physiquement, supprimés logiquement compris.

## 5. Écrans

### Fiche élève (`/students/:id`), carte « Progression par bloc »

```
Bloc « Rejet naturel »                 [ Acquis au positionnement ]
████████████████ 100 %
6 exercices sur 6
Acquis au positionnement le 12 oct.
3 séances (compteur existant)
[ Retirer l'acquis ]

Bloc « Posture »                       [ Non commencé ]
░░░░░░░░░░░░░░░░  0 %
0 exercice sur 5
[ Marquer le bloc acquis ]
```

- « Marquer le bloc acquis » : proposé aux blocs non acquis (y compris
  « en cours » ; pas aux blocs « Acquis » par passages). Ouvre une boîte
  « Marquer le bloc acquis » : texte « Les N exercices de ce bloc compteront
  comme validés, sans passage enregistré. Un passage saisi à cette date
  ou après reprend la main sur son exercice. », sélecteur de date (jour courant par défaut,
  jamais dans le futur), « Marquer acquis » / « Annuler ».
- « Retirer l'acquis » : confirmation « Retirer l'acquis du bloc « … » ? Ses
  exercices redeviennent à valider selon les passages saisis. » ; retour
  « Acquis retiré. ».
- Marqueur partiellement repris : le bloc s'affiche selon ses résultats (les
  exercices encore acquis comptent validés), avec la ligne « Acquis au
  positionnement le 12 oct. ; 2 exercices repris par les passages saisis
  depuis » ; « Retirer l'acquis » reste proposé (supprime le marqueur et rend
  à valider les exercices encore acquis). Marqueur dormant (tous les exercices
  repris) : même ligne, bloc dérivé des seuls passages, « Retirer l'acquis »
  supprime le marqueur dormant.
- Composant des retours : `placementMarked` et `placementRevoked` s'affichent
  dans une `SnackBar` de la page `student_sheet` ; une erreur de saisie
  (`dateInFuture`, `blockAlreadyAcquired`) s'affiche sous le sélecteur de date
  de la boîte, via `failureMessage`.
- Retour après action : message « Bloc marqué acquis : Rejet naturel », le
  compteur « n / 72 » et l'exercice suivant se recalculent (rechargement de
  `StudentSheetBloc`).
- Accessibilité : les boutons portent le nom du bloc (« Marquer le bloc
  acquis : Posture ») ; le statut est icône + libellé, jamais la couleur seule.

### Séance suggérée

Inchangée visuellement. Mention des blocs sautés : hors lot (§ 9).

## 6. Découpage FSD

| Couche | Slice | Ajouts / modifications |
|---|---|---|
| `shared` | `lib` | `AcquisitionId` ; `InvariantCode.blockAlreadyAcquired`, `backupUnknownBlock` (`unknownBlock` existe déjà) |
| `shared` | `ui` | `failure_message.dart` : cas `blockAlreadyAcquired`, `backupUnknownBlock` du `switch` exhaustif |
| `shared` | `persistence` | table `BlockAcquisitions`, schéma v5, `from4To5`, instantanés |
| `shared` | `l10n` | `shared/l10n/app_fr.arb` et `app_en.arb` : clés `placement*`, `statusAcquiredAtPlacement`, `failBlockAlreadyAcquired`, `failBackupUnknownBlock` |
| `entities` | `block_acquisition/domain` | entité, source, port |
| `entities` | `block_acquisition/data` | dépôts drift et mémoire |
| `entities` | `exercise_result/domain` | `StudentProgress.derive(acquisitions)`, `acquiredBlocks`, `acquiredExercises`, `resumedExercises`, `validated`, `activeAlerts` |
| `features` | `place_student/domain` | `MarkBlockAcquired`, `RevokeBlockAcquired` |
| `features` | `place_student/presentation` | `PlacementBloc` (événements `markRequested`, `revokeRequested` ; états `idle`, `done(change)`, `refused(failure)`), `acquire_block_dialog.dart` |
| `features` | `track_progress/domain` | `BlockStatus.acquiredAtPlacement`, `BlockProgress.acquiredOn` / `resumedCount`, `StudentReport.derive`, `GetStudentSheet`, `GetStudentReport` |
| `features` | `track_progress/presentation/ui` | `block_progress_list.dart` : badge, date, boutons par callbacks |
| `features` | `suggest_session/domain` | `SuggestSession`, `SuggestRecall` lisent les marqueurs |
| `features` | `manage_students/domain` | `GetClubOverview`, `EraseStudent` (constructeur, docstring, test unitaire) |
| `features` | `record_results/domain` | `RecordAttempt` lit les marqueurs ; `RecordedAttempt.resumedFromPlacement`, `justValidated` |
| `features` | `record_results/presentation` | message de reprise sur la saisie |
| `features` | `backup_data/domain` | snapshot, encodeur, décodeur, références, règles, unicité, résumé |
| `pages` | `student_sheet` | compose `PlacementBloc` ; rechargement de la fiche |
| `app` | `di`, `router` | enregistrement ; fourniture du bloc à la page |
| `widgetbook/lib/use_cases` | | `BlockProgressList` (acquis, repris, non acquis), boîte de dialogue |

Règle de dépendance : aucune feature n'importe une autre feature ; la page
compose les blocs et transmet les callbacks.

## 7. Internationalisation (fr / en)

| Clé | fr | en |
|---|---|---|
| `placementMarkAction` | Marquer le bloc acquis | Mark block as acquired |
| `placementMarkActionFor` (nom du bloc) | Marquer le bloc acquis : {block} | Mark block as acquired: {block} |
| `placementDialogTitle` | Marquer le bloc acquis | Mark block as acquired |
| `placementDialogBody` ({count}) | Les {count} exercices de ce bloc compteront comme validés, sans passage enregistré. Un passage saisi à cette date ou après reprend la main sur son exercice. | The {count} exercises in this block will count as validated, with no recorded pass. A pass recorded on or after this date takes over for its exercise. |
| `placementDateLabel` | Date du positionnement | Placement date |
| `placementConfirm` | Marquer acquis | Mark as acquired |
| `placementRevokeAction` | Retirer l'acquis | Remove acquired status |
| `placementRevokeTitle` ({block}) | Retirer l'acquis du bloc « {block} » ? | Remove acquired status for “{block}”? |
| `placementRevokeBody` | Les exercices redeviennent à valider selon les passages saisis. | Exercises go back to being validated from recorded passes. |
| `placementMarked` ({block}) | Bloc marqué acquis : {block} | Block marked as acquired: {block} |
| `placementRevoked` | Acquis retiré. | Acquired status removed. |
| `statusAcquiredAtPlacement` | Acquis au positionnement | Acquired at placement |
| `placementOn` ({date}) | Acquis au positionnement le {date} | Acquired at placement on {date} |
| `placementResumed` ({date}, {count}) | Acquis au positionnement le {date} ; {count, plural, one{# exercice repris} other{# exercices repris}} par les passages saisis depuis | Acquired at placement on {date}; {count, plural, one{# exercise} other{# exercises}} taken over by passes recorded since |
| `placementResumedFeedback` | Exercice acquis au positionnement : les passages reprennent la main sur cet exercice. | Exercise acquired at placement: recorded passes now take over this exercise. |
| `failBlockAlreadyAcquired` | Ce bloc est déjà marqué acquis pour cet élève. | This block is already marked as acquired for this student. |
| `failBackupUnknownBlock` | La sauvegarde cite un bloc inconnu du catalogue. | The backup refers to a block unknown to the catalogue. |
| `failDateInFuture` (existante) | La date ne peut pas être dans le futur. | réutilisée sous le sélecteur de date |

`scripts/check.sh --full` (`check_l10n`) exige les mêmes clés en fr et en ; la
casse « Acquis » (validé par passages) et « Acquis au positionnement » ne
doivent pas être interchangées.

## 8. Scénarios BDD (rouge avant le code)

`test/bdd/block_placement.feature` (nouveau) :

1. La fiche d'un élève sans passage propose « Marquer le bloc acquis » sur
   chaque bloc et affiche « 0 / 72 ».
2. Marquer un bloc acquis le montre « Acquis au positionnement » avec sa date et
   fait passer le compteur de « 0 / 72 » au nombre d'exercices du bloc.
3. L'exercice suivant de la fiche saute le bloc acquis et reste dans l'ordre
   d'enseignement (rebond sur bande avant rejet naturel).
4. Marquer deux blocs acquis cumule leurs exercices dans le compteur.
5. Une date dans le futur est refusée avec un message sous la boîte.
6. Annuler la boîte ne marque rien.
7. Retirer l'acquis (après confirmation) remet le bloc « Non commencé » et le
   compteur à son état précédent ; annuler la confirmation conserve l'acquis.
8. Un passage saisi après la date reprend la main **sur son exercice
   seulement** : le reste du bloc reste « acquis au positionnement » et le
   compteur ne perd que cet exercice (pas le bloc entier).
9. Un passage saisi le **même jour** que le positionnement reprend la main sur
   son exercice ; un passage daté d'**avant** le positionnement ne reprend pas
   la main.
10. Un bloc acquis par passages n'offre pas « Marquer le bloc acquis ».
11. Le bloc partiellement repris affiche « Acquis au positionnement le … ;
    N exercices repris par les passages saisis depuis » et reste proposé à
    « Retirer l'acquis ».
12. Une alerte ancienne (échecs consécutifs) sur un exercice d'un bloc acquis
    est masquée ; elle redevient visible quand cet exercice est repris.
13. Un bloc acquis n'est jamais affiché « en retard » ni « à revoir ».
14. « Retirer l'acquis » d'un marqueur dormant (tous exercices repris) le
    supprime sans changer le compteur.
15. Après marquage, rouvrir la fiche (rechargement) conserve le marqueur et le
    compteur.
16. Le libellé « Acquis au positionnement » est distinct de « Acquis » (bloc
    validé par passages).
17. Un bloc `[Prop]` peut être marqué acquis et garde sa pastille.
18. Accessibilité : le bouton porte le nom du bloc (« Marquer le bloc acquis :
    Posture »).

`test/bdd/record_results.feature` (existant) : saisir un passage sur un
exercice acquis au positionnement affiche le message de reprise, ne déclenche
pas « exercice validé » et recalcule l'exercice suivant.

`test/bdd/suggested_session.feature` (existant) : un groupe dont tous les élèves
ont le bloc « Posture » acquis se voit suggérer le bloc suivant dans l'ordre
d'enseignement.

`test/bdd/data_backup.feature` : une sauvegarde exportée avec un bloc acquis est
restaurée à l'identique ; un fichier avec un bloc inconnu est refusé.

Effacement : aucun fichier `.feature` d'effacement n'existe ; le scénario
« effacer un élève supprime ses blocs acquis » s'ajoute à
`test/bdd/students.feature` (existant, avec `students_test.dart`), et la
suppression physique reste couverte par
`test/unit/shared/persistence/physical_erasure_test.dart`.

Unitaires (TDD) : `BlockAcquisition` (invariants) ; `StudentProgress.derive`
(exercice acquis, repris le même jour ou après, non repris si antérieur, reste
du bloc acquis, bloc inconnu ignoré, plusieurs marqueurs, alertes masquées,
`validated`) ; `RecordAttempt` (`resumedFromPlacement`, `justValidated` faux
sur exercice acquis, `nextExercise`) ; `BlockProgress.of`
(statut, `overdue`) ; `StudentReport.derive` (compteur, `resumedCount`) ;
`planSession` (bloc acquis sauté, ordre inchangé, `nothingToTeach`) ;
`MarkBlockAcquired`, `RevokeBlockAcquired` (chaque erreur) ; `PlacementBloc` ;
codec de sauvegarde (clé `blockAcquisitions` absente → `backupInvalid`) ; contrat de repository (drift et mémoire, suppression
logique, effacement physique) ; migration v4 → v5.

## 9. Points ouverts

1. **Même jour** (tranché) : un passage daté du jour du positionnement
   reprend la main sur son exercice (`>=` sur `dateOnly`). Un animateur qui
   marque l'acquis après avoir saisi la séance du jour verra donc cet exercice
   repris : il peut corriger ou supprimer le passage (ADR 0006). À revoir à
   l'usage.
2. **Séance suggérée** : indiquer « blocs acquis au positionnement ignorés »
   dans la séance suggérée (aujourd'hui seule la fiche élève le dit).
3. **Grille de positionnement en lot** à la création d'un élève ou à la rentrée.
4. **Marquage par exercice** si un bloc n'est maîtrisé qu'à moitié.
5. **Positionnement et rappel** : un bloc acquis n'est jamais rappelé
   (aucun résultat) ; accepté tant que l'animateur peut le rejouer en séance.
6. **Blocs `[Prop]`** : les marquer acquis est permis ; la pastille
   `ProposalBadge` reste visible (scénario BDD 17).

## 10. Lots

| Lot | Contenu | Critère de fin |
|---|---|---|
| B1 | Plan, ADR, scénarios BDD + steps (rouge) | `.feature` générés, tests rouges constatés |
| B2 | Domaine (TDD) : `BlockAcquisition`, port, `StudentProgress.derive`, `BlockProgress`, `StudentReport`, `planSession`, appelants (dont `RecordAttempt`), `MarkBlockAcquired`, `RevokeBlockAcquired`, dépôts mémoire | tests unitaires et contrat mémoire verts |
| B3 | Persistance : table, schéma v5, `from4To5`, dépôt drift, effacement | `migration_test`, contrat drift et `physical_erasure_test` verts |
| B4 | Sauvegarde : snapshot, encodeur, décodeur, règles, résumé | contrat de sauvegarde et `data_backup` verts |
| B5 | Bloc `PlacementBloc`, l10n fr / en, UI (fiche, boîte de dialogue), routeur, Widgetbook | scénarios BDD verts, `check_l10n`, `check_widgetbook` verts |
| B6 | Docs (`architecture.md`, ADR 0001, ADR 0003, `guide-animateur.md`, roadmap, adr/README), `check.sh --full`, revues `architecte-fsd` + `testeur-bdd` | tout vert, revues sans réserve bloquante |

## 11. Risques

- `StudentProgress.derive` est appelé en six endroits : le paramètre
  obligatoire fait échouer la compilation d'un oubli ; chaque appelant a un
  test avec un bloc acquis.
- `BlockStatus` gagne une valeur : tous les `switch` exhaustifs (badge, filtre,
  Widgetbook) cessent de compiler tant qu'ils ne la traitent pas, voulu.
- Compteur « n / 72 » : un passage sur un exercice acquis fait baisser le
  compteur d'un exercice au plus ; la ligne « N exercices repris » et le
  message de saisie l'expliquent.
- Migration additive (`createTable`) : risque faible ; test sur base v4 avec
  données.
- Sauvegarde : la clé `blockAcquisitions` est obligatoire ; un fichier produit
  avant ce lot est refusé (`backupInvalid`), assumé (V1 non livrée).
- Effacement d'élève : oublier la table nouvelle laisserait un identifiant
  d'élève mineur en base ; couvert par `physical_erasure_test`.
