# Historique des séances saisies et correction des passages : plan

> **Amendé par l'[ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md) (décision 17, réalisée en FB4c)** : le rang d'un passage est **dérivé** de l'ordre d'enregistrement ; `passIndex` n'existe plus et la suppression **ne renumérote plus**. Les passages ci-dessous sur `passIndex` et la renumérotation sont conservés tels que livrés.

Statut : **livré** (lot 5 de la [roadmap](roadmap.md) ; conception validée
par l'utilisateur et lots H1 à H5 réalisés le 2026-10-14, `scripts/check.sh
--full` vert, revues `architecte-fsd` et `testeur-bdd` prises en compte).
Décision : [ADR 0006](adr/0006-historique-et-correction-des-passages.md).
Contexte : application V1 non livrée, aucune compatibilité de données à
préserver. Règles de développement : `AGENTS.md`, skills `dev-feature`,
`dev-bdd`, `dev-tdd` ; `architecture.md`, `testing.md`, `quality-gates.md`,
`design-system.md`, `i18n.md`.

## 1. Constat et objectif

L'onglet **Résultats** ouvre directement le formulaire « groupe, présents,
date ». Une séance saisie n'est ensuite visible nulle part : ni liste, ni
relecture, ni correction d'un passage mal saisi (friction F5 de la roadmap).
Objectif : voir les séances données, les rouvrir, corriger ou supprimer un
passage, et lire l'assiduité d'un élève.

## 2. Décisions (reprises de l'ADR 0006)

1. `/record` devient l'**historique** ; le formulaire passe à `/record/new`
   (déclarée avant `/record/:sessionId`, comme `/students/new`). Tous les liens
   profonds vers le formulaire (séance guidée, suggestion) visent `/record/new`
   avec les mêmes paramètres.
2. La page `/record/:sessionId` reste la saisie ; sa section « Passages de la
   séance » gagne **Modifier** et **Supprimer** par ligne.
3. Un passage se corrige **en place** (`add` d'un id connu = remplacement,
   contrat déjà garanti) avec les invariants de la saisie ; une suppression
   **renumérote** les `passIndex` restants du même élève / exercice / séance
   dans une unité de travail.
4. Aucune méthode ajoutée aux ports ; sauvegarde inchangée.
5. Assiduité d'un élève = séances où il était présent / séances de ses groupes
   aux dates où il en était membre (`Group.isMemberOn`), sur la fiche élève.
6. Hors lot : modifier les présents d'une séance passée (reste possible par
   `/record/new`, même groupe et même date), supprimer une séance entière.

## 3. Écrans

### Historique (`/record`)

```
Séances saisies
Les séances données, de la plus récente à la plus ancienne.
[ Nouvelle séance ]
┌ Séance du mar. 13 oct. ───────────────────────── ›
│ Groupe enfants · Enfants · Notion principale : …
│ 3 présents · 4 passages
└
(vide : « Aucune séance saisie pour le moment. »)
```

Chaque ligne est un bouton sémantique « Ouvrir la séance du {date} ({groupe}) ».

### Saisie (`/record/:sessionId`), section « Passages de la séance »

```
Léa · La puissance · exercice 1 : 7 sur 9      [✎] [🗑]
```

- ✎ ouvre une boîte « Modifier le passage » avec les deux `CounterField`
  (billes, tentatives ; tentatives ≥ celles de la fiche), bouton « Enregistrer
  la correction ». Retour : « Passage corrigé : 7 sur 9 » ; refus affiché sous
  la liste.
- 🗑 demande confirmation (« Supprimer ce passage ? », rappel du passage, « le
  résultat et la courbe de l'élève seront recalculés »). Retour : « Passage
  supprimé. »

### Fiche élève

Carte « Assiduité » : « Présent à N séances sur M » ; « Aucune séance du groupe
pour le moment. » quand M = 0.

## 4. Découpage FSD

| Couche | Fichiers |
|---|---|
| `features/record_results/domain` | `recorded_session_summary.dart`, `list_recorded_sessions.dart`, `correct_attempt.dart`, `delete_attempt.dart` |
| `features/record_results/presentation/bloc` | `recorded_sessions_bloc.dart` (+ event, state) ; `record_results_bloc.dart` : événements `attemptCorrected`, `attemptDeleted`, état `attemptChange` (union `AttemptChange.corrected` / `.deleted`) et `attemptRefused` |
| `features/record_results/presentation/ui` | `recorded_session_list.dart`, `attempt_history.dart` (lignes + actions), `attempt_edit_dialog.dart` |
| `features/track_progress/domain` | `attendance.dart` (fonction pure + valeur), `StudentReport.attendance` ; `GetStudentSheet` et `GetStudentReport` lisent `GroupRepository.all()` et `SessionRecordRepository.all()`, le filtrage par appartenance étant fait par `attendanceOf` (la duplication entre ces deux cas d'usage préexiste ; à résorber dans un lot dédié) |
| `features/track_progress/presentation/ui` | `student_sheet_view.dart` : carte Assiduité |
| `pages/record_history/presentation` | `record_history_page.dart` |
| `app` | `router.dart` (`AppRoutes.newRecord`, routes), `shell.dart` inchangé |
| `shared/l10n` | clés `history*`, `recordEdit*`, `recordDelete*`, `sheetAttendance*` en fr et en |
| `widgetbook/lib/use_cases` | un cas par widget et pour la page |

Règle de dépendance : aucune feature n'importe une autre feature ; la page
compose les blocs fournis par le routeur.

## 5. Domaine : règles

- `ListRecordedSessions` : `SessionRecordRepository.all()`, nom du groupe
  (`GroupRepository.byId`), titre du bloc principal (catalogue), nombre de
  présents et de passages (`AttemptRepository.forSession`) ; tri par date
  décroissante, puis ordre d'enregistrement décroissant.
- `CorrectAttempt(sessionId, attemptId, potted, total)` : `NotFound('attempt')`
  si le passage n'est pas dans la séance ; `unknownExercise`,
  `totalBelowSheet` ; invariants de `ExerciseAttempt` (`pottedExceedsTotal`,
  `totalOutOfRange`, `negativePotted`) ; `add(copyWith)`. Retourne le passage
  corrigé.
- `DeleteAttempt(sessionId, attemptId)` : `NotFound('attempt')` ; dans
  `UnitOfWork.run` : `delete(id)` puis, pour les passages restants du même
  élève / exercice / séance triés par `passIndex`, `add(copyWith(passIndex:
  i + 1))` quand l'index change. Tout ou rien.
- `attendanceOf(studentId, sessions, groups)` : `total` = séances dont le
  groupe compte l'élève membre à la date de la séance ; `attended` = celles où
  il est présent. Valeur `(attended, total)`.

## 6. Scénarios BDD (rouge avant le code)

`test/bdd/record_history.feature` :

1. L'onglet Résultats ne liste aucune séance au départ (et propose « Nouvelle
   séance »).
2. Une séance saisie apparaît avec sa date, son groupe, ses présents et ses
   passages.
3. La séance la plus récente vient en premier.
4. Une séance s'ouvre depuis l'historique.
5. « Nouvelle séance » ouvre le formulaire.
6. Corriger un passage met à jour la séance et le résultat de l'élève (la
   notion à rappeler disparaît).
7. Supprimer un passage demande confirmation, libère un créneau dans la séance
   et l'historique compte un passage de moins.
8. Annuler la suppression conserve le passage.

`student_sheet.feature` : l'assiduité compte les séances du groupe.
`screen_navigation.feature`, `session_guide.feature` : adresses `/record` du
formulaire → `/record/new`. `navigation` : l'onglet Résultats affiche
l'historique.

Unitaires : les trois cas d'usage (invariants, `NotFound`, renumérotation,
tout-ou-rien), `attendanceOf`, `RecordedSessionsBloc`, `RecordResultsBloc`
(correction, suppression, refus), `AppRoutes`.

## 7. Lots

| Lot | Contenu | Critère de fin |
|---|---|---|
| H1 | Scénarios BDD + steps (rouge), plan et ADR | `.feature` généré, tests rouges constatés |
| H2 | Domaine : `ListRecordedSessions`, `CorrectAttempt`, `DeleteAttempt`, `attendanceOf` (TDD) | tests unitaires verts |
| H3 | Blocs (TDD), l10n fr/en, routes | `bloc_test` verts, `check_l10n` vert |
| H4 | UI : historique, actions sur les passages, carte Assiduité, Widgetbook | scénarios BDD verts, `check_widgetbook` vert |
| H5 | Docs (`architecture.md`, `guide-animateur.md` § 4, ADR 0003, roadmap), `check.sh --full`, revues `architecte-fsd` + `testeur-bdd` | tout vert, revues sans réserve bloquante |

## 8. Risques

- Deux passages identiques dans une séance (même score) : les actions par ligne
  sont distinguées par leur position, pas par leur texte ; les scénarios
  utilisent des scores différents.
- La renumérotation réécrit des passages (`updatedAt` change) : sans effet sur
  la dérivation des résultats, qui ne lit que `date` et `passIndex`.
- Changement d'adresse du formulaire : tous les liens sont construits par
  `AppRoutes` ; un test unitaire fige `/record/new`.
