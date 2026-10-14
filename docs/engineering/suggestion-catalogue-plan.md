# Suggestion ↔ catalogue : plan

Statut : **livré** (lot 8 de la [roadmap](roadmap.md), 2026-10-14) ;
arbitrages S1 à S8 intégrés ; écarts à la livraison en § 12. Décision :
[ADR 0009](adr/0009-suggestion-seance-du-catalogue.md). Contexte : application
V1 non livrée, aucune compatibilité de données à préserver. Règles de
développement : `AGENTS.md`, skills `dev-feature`, `dev-bdd`, `dev-tdd` ;
`architecture.md`, `testing.md`, `quality-gates.md`, `design-system.md`,
`i18n.md`.

## 1. Constat et objectif

La séance suggérée pointe un **bloc** et des exercices ; le catalogue contient
des **séances** (29, 13 blocs sur 15 en ont 2 à 4). Le lien n'existe que dans
le sens séance → bloc (`ResolveSheetBlocks`). La saisie ouverte depuis la
suggestion n'a pas de `sheetId`. Objectif : depuis la séance suggérée,
proposer la **séance du catalogue correspondante** (partie suivante non faite
par le groupe), l'ouvrir, la lancer, la planifier ou noter ses résultats sans
rien ressaisir, et noter la partie donnée pour que la suivante soit la bonne.

## 2. Décisions (reprises de l'ADR 0009)

1. `planSession` inchangé ; fonction pure `suggestSheet` en aval ;
   `SessionPlan.sheet` (`SheetSuggestion?`, nul = bloc sans séance).
2. Règle : candidates du bloc → moins faites → moins sans objet → celle qui
   contient l'exercice de tête, sinon la première ; tout fait → celle qui
   contient l'exercice de tête (« déjà donnée le … »).
3. « Faite » = saisie du groupe avec `sheetId` **et** au moins un passage
   rattaché, datée d'aujourd'hui ou avant (S7). Planifiée non saisie, saisie
   sans séance, saisie sans passage, saisie future : ne comptent pas.
4. Séance qui ne contient pas la tête : exercices non validés de la séance +
   note sur la tête (S3).
5. Actions : Ouvrir, Lancer (avec le groupe, S6), Planifier ; « Saisir »
   transmet `sheet` par `AppRoutes.recordFromSuggestion`.
6. Bloc sans séance (cas nominal, S8) : message + exercices du bloc, Saisir et
   Planifier conservés.
7. Échec du chargement des séances : la suggestion échoue (écran d'erreur
   existant).
8. Aucune migration drift, sauvegarde inchangée.

## 3. Modèle de domaine

### `SheetSuggestion` (`features/suggest_session/domain/sheet_suggestion.dart`)

Valeur immuable (freezed) : `option` (`SheetOption` de
`entities/session_sheet` : identifiant, technique, `techniqueRank`, titre,
partie, nombre de parties), `kind` (`SheetSuggestionKind` : `coversHead`,
`nextPending`, `repeat`), `exerciseNumbers` (numéros du bloc contenus dans la
séance), `headCovered` (la séance contient l'exercice de tête), `head`
(`ExerciseRef`), `lastGivenOn` (`DateTime?` : jour calendaire local de la
saisie **faite** la plus récente de la séance ; renseigné pour `repeat`, nul
sinon).

### Fonction pure `suggestSheet`

Entrées (7, comme l'ADR) :

| Entrée | Type | Rôle |
|---|---|---|
| `mainBlockId` | `String` | bloc principal du plan |
| `head` | `ExerciseRef` | premier exercice du plan |
| `sheets` | `Iterable<SessionSheet>` | séances ; `SheetOption` ne suffit pas (pas de `catalogueBlock` ni d'exercices) ; `option` s'obtient par `sheetOptionOf(sheets, id)` |
| `groupSessions` | `List<SessionRecord>` | saisies du groupe |
| `attemptCountBySession` | `Map<SessionId, int>` | passages par saisie (les saisies sans entrée valent 0) |
| `today` | `DateTime` | jour courant, fourni par `Clock` (`shared/lib/clock.dart`) |
| `validatedByAll` | `Set<ExerciseRef>` | intersection des `StudentProgress.validated` des élèves attendus (acquis du lot 7 compris) ; **vide** si aucun élève |

Sortie : `SheetSuggestion?`. Pas d'effet de bord, pas d'erreur : séances ou
identifiants inconnus sont ignorés.

Table de décision (bloc `coule`, parties `coule-1` 1-3, `coule-2` 4-6,
`coule-3` 7-8) :

| Faites par le groupe | Validation / tête | Résultat | Raison |
|---|---|---|---|
| aucune | tête 1 | `coule-1` | `coversHead` |
| aucune | tête 5 | `coule-2` | `coversHead` |
| aucune ; A a validé 1-3, B rien (hétérogène) | tête 5 | `coule-2` (pas `coule-1`) | `coversHead` — **scénario discriminant S1** |
| `coule-1` | tête 2 (non validé) | `coule-2` | `nextPending` (tête dans une partie faite) ; exercices = non validés de `coule-2` + note sur la tête |
| `coule-2` | tête 1 | `coule-1` | `coversHead` (partie sautée reproposée) |
| `coule-1`, `coule-2`, `coule-3` | tête 5 | `coule-2` | `repeat`, « déjà donnée le … » (S4) |
| aucune ; 4-6 validés par tous | tête 7 | `coule-3` | `coversHead` (`coule-2` sans objet) |
| `coule-1` ouverte sans passage | tête 1 | `coule-1` | `coversHead` (S7) |
| `coule-1` avec passage, datée demain | tête 1 | `coule-1` | `coversHead` (S7) |
| — | — | `null` | `quantites-de-billes`, `trajectoires-blanche` |

Cas `quart-finesses` : `quart-1` (1-2) puis `finesse-1` (3-4), par `order`.

### Cas limites

- **Bloc sans séance** (`C` vide) : `null`. Atteint à coup sûr :
  `quantites-de-billes` (`teaching_order` 8) et `trajectoires-blanche` (15)
  sont parcourus par `ExerciseCatalogue.nextExercise`. Scénario BDD avec un
  groupe positionné juste avant `teaching_order` 8 ; UI de repli § 5.
- **Toutes faites** : `repeat` sur la séance contenant la tête. Pas de branche
  « dernière séance » : un test de couverture du catalogue réel vérifie que
  chaque exercice d'un bloc à séances est dans exactement une séance du bloc.
- **Plusieurs saisies pour une même séance** : `lastGivenOn` = la plus récente.
- **Bloc acquis (lot 7)** : un bloc acquis par tout le groupe n'est jamais
  `mainBlockId` ; acquis par une partie du groupe, il reste proposé ; les
  parties dont tous les exercices sont validés / acquis par chaque élève sont
  « sans objet ». Une partie contenant l'exercice de tête n'est jamais sans
  objet.
- **Élève ajouté / retiré** : `validatedByAll` change, donc `O` et la séance
  (voulu) ; groupe sans élève : `noStudents` avant tout calcul.
- **Identifiant de séance inconnu** : ignoré, jamais d'erreur.
- **Public** : sans effet sur le choix ; le rendu (90 / 120 min) vient de
  `plan.audience`, transmis au guide et au planificateur.
- **Rappel** : inchangé (`selectRecall`) ; le rappel suggéré (échec / alerte)
  prime sur celui dérivé de la séance (`resultsRecallBlock`, ADR 0007).

### Impact sur `SuggestSession` (`features/suggest_session/domain`)

- Injecte `SessionSheetRepository` (`getAll()`) et `Clock`.
- Après `planSession` : lit les passages de chaque saisie du groupe ayant un
  `sheetId` (`AttemptRepository.forSession`), calcule `validatedByAll`, appelle
  `suggestSheet`, retourne `plan.copyWith(sheet: …)` ; si la séance ne contient
  pas la tête, remplace aussi `plan.exercises` par les exercices de la séance
  non validés par tout le groupe (vérifier au lot C2 que durée et phases ne
  dépendent pas de leur nombre).
- Échec de `SessionSheetRepository.getAll()` : `Err` via `runGuarded`, pas de
  dégradation.
- `SuggestRecall` et `RecordAttempt` : inchangés.

## 4. Persistance

Aucune. `SessionRecord.sheetId` (schéma v4, ADR 0007),
`ExerciseAttempt.sessionId` et le catalogue (asset) existent déjà. Pas de
schéma v6, `BackupCodec` inchangé.

## 5. Écrans

### Séance suggérée (`/session`, `SessionPlanView`)

Nouvelle carte **« Séance du catalogue »** sous « Notion principale » :

- séance proposée : titre + `l10n.sheetPartLabel(part, parts)` existant
  (« Séance 2/2 ») ; sous-titre selon `kind` : « Une partie encore à faire pour ce
  groupe » (`nextPending`), « Couvre l'exercice de tête de la suggestion »
  (`coversHead`), « Déjà donnée le 3 oct. » (`repeat`) ;
- si `headCovered` est faux : note « L'exercice de tête (n° 2) relève d'une
  partie déjà donnée » ; la liste des exercices est celle de la séance
  (non validés) ;
- actions : **Ouvrir la séance** (`AppRoutes.sheet(id, audience:)`),
  **Lancer la séance guidée** (`AppRoutes.guide(id, audience:, group:)`),
  **Planifier** (`AppRoutes.plan(id, audience:)`) ;
- **sans séance (S8)** : « Aucune séance du catalogue pour cette notion : les
  exercices du bloc sont listés ci-dessous » ; liste = exercices du plan
  actuel ; pas d'« Ouvrir » ni de « Lancer » ; **Planifier** ouvre
  `AppRoutes.planner` sans `sheet` (`AppRoutes.plan` accepte `SheetId?`) ;
  **Saisir** sans `sheet`.

Le bouton **« Saisir les résultats de cette séance »** appelle
`onRecord(group, main, recall, sheet?)` ; le routeur construit l'adresse par
`AppRoutes.recordFromSuggestion({group, main, recall, sheet})` (aujourd'hui
`/session` assemble un `Uri` à la main : closure remplacée, constructeur
testé comme `recordFromGuide` / `recordFromPlan`). `SessionPlanView` reçoit
`onOpenSheet`, `onLaunch`, `onPlan`. `SuggestedSessionBloc` et son état n'ont
rien à ajouter (le plan porte la proposition et les exercices).

### Séance guidée (S6)

`AppRoutes.guide(…, group:)` ; `RunKey` gagne `group` (égalité et hash) ;
`_runKey` et `_guideKey` du routeur le lisent ; la saisie ouverte depuis ce
guide reçoit le groupe par `recordFromGuide(group:)`, comme depuis une séance
planifiée.

### Saisie

Inchangée : le sous-titre nomme déjà la séance du catalogue (ADR 0007).

## 6. Découpage FSD

| Couche | Slice | Ajouts / modifications |
|---|---|---|
| `features` | `suggest_session/domain` | `SheetSuggestion`, `SheetSuggestionKind`, `suggestSheet`, `SessionPlan.sheet`, `SuggestSession` (+ `SessionSheetRepository`, `Clock`) |
| `features` | `suggest_session/presentation` | `SessionPlanView` : carte, note, repli, 3 callbacks |
| `features` | `run_sheet/presentation` | `RunKey.group`, `RunSheetSessions` (clé) |
| `pages` | `suggested_session` | `onRecord(group, main, recall, sheet)` : doc et tests existants mis à jour ; `onOpenSheet`, `onLaunch`, `onPlan` |
| `pages` | `sheet_guide` | prise en compte de `group` si la page le relaie |
| `app` | `router` | `AppRoutes.recordFromSuggestion`, `guide(group:)`, `plan(SheetId?)`, `_runKey`, `_guideKey`, câblage `/session` |
| `entities` | `session_sheet/domain` | aucun changement |
| `shared` | `l10n` | clés fr / en (§ 7) |

Aucune feature n'importe une autre feature ; `suggest_session` n'utilise que
des entités et `shared`.

## 7. Internationalisation (fr / en)

Clés ajoutées à `app/lib/shared/l10n/app_fr.arb` et `app_en.arb`, mêmes noms :
`suggestSheetTitle` (« Séance du catalogue » / « Catalogue session »),
`suggestSheetNextPending`, `suggestSheetCoversHead`, `suggestSheetRepeat(date)`,
`suggestSheetHeadElsewhere(number)` (note S3), `suggestSheetNone` (S8),
`suggestSheetOpen`, `suggestSheetLaunch`, `suggestSheetPlan`. Le libellé de
partie **réutilise** `sheetPartLabel` (pas de `suggestSheetPartLine`). Aucun
texte en dur, `scripts/generate.sh` relancé, clés identiques fr / en.

## 8. Scénarios BDD (rouge avant le code)

Langue : `suggested_session.feature` en français, `suggested_session_screen.
feature` en anglais (conventions existantes de chaque fichier).

`test/bdd/suggested_session.feature` (domaine) :

- Sans séance donnée, la suggestion propose la partie 1 (« posture » →
  `posture-1`).
- Une partie déjà donnée (saisie avec séance et passage) n'est pas reproposée :
  `posture-1` donnée, la suggestion propose `posture-2`.
- Une partie sautée est reproposée : `coule-2` donnée, tête 1 → `coule-1`.
- **L'exercice de tête décide (S1, discriminant)** : groupe hétérogène, A a
  validé 1 à 3 de `coule`, B rien, tête 5 → `coule-2` et non `coule-1`.
- Toutes les parties faites : la séance contenant la tête, « déjà donnée le … »
  (S4).
- Plusieurs saisies pour une même partie : `lastGivenOn` = la plus récente.
- Une saisie sans séance du catalogue ne compte pas (S2).
- Une saisie ouverte sans passage ne compte pas ; reprise le même jour avec un
  `sheet` différent : la partie n'est pas donnée (S7).
- Une saisie datée du futur ne compte pas (S7).
- Une séance **planifiée non saisie** ne compte pas (S5).
- Un `sheetId` inconnu du catalogue est ignoré, sans erreur.
- `nextPending` : la séance ne contient pas la tête, les exercices sont ceux
  non validés de la séance et la tête est signalée.
- Le rappel suggéré (échec / alerte) prime sur le rappel dérivé de la séance.
- Le bloc partagé `quart-finesses` : `quart-1` puis `finesse-1`.
- **Bloc sans séance (S8, nominal)** : groupe positionné juste avant
  `quantites-de-billes` (`teaching_order` 8) → aucune séance proposée, exercices
  du bloc listés, pas d'erreur.
- Un bloc acquis par tout le groupe n'est pas proposé ; une partie dont tous
  les exercices sont acquis est sautée.
- Le public ne change pas la séance proposée (limité à la vérification du
  `sheet` : la durée est déjà couverte par le feature existant).
- Le catalogue de séances ne se charge pas : la suggestion échoue (`Err`).

`test/bdd/suggested_session_screen.feature` (écran) : la carte « Séance du
catalogue » affiche titre et partie ; la note de tête s'affiche pour
`nextPending` ; « Ouvrir la séance » ouvre le catalogue ; « Lancer la séance
guidée » ouvre le guide **avec le groupe** et « Noter » depuis ce guide
pré-remplit le groupe (S6) ; « Planifier » préselectionne la séance au
planificateur ; « Saisir les résultats » ouvre `/record/new` avec groupe,
notion et séance, et la saisie nomme la séance ; bloc sans séance → message de
repli, « Saisir » et « Planifier » présents, « Ouvrir » et « Lancer » absents.

Tests unitaires : `suggest_sheet_test.dart` (table du § 3, `validatedByAll`
vide), couverture du catalogue réel (chaque exercice dans exactement une
séance de son bloc), extension de `suggest_session_test.dart`,
`AppRoutes.recordFromSuggestion` / `guide(group:)` / `RunKey`, tests de
`SessionPlanView` et de la page.

## 9. Arbitrages

Tous tranchés (2026-10-14), détail dans l'ADR 0009 : S1 tête d'abord ; S2
saisie sans séance ne compte pas ; S3 exercices de la séance + note sur la
tête ; S4 partie contenant la tête, « déjà donnée » ; S5 planifiée non saisie
ne compte pas, hors lot ; S6 `group` au guide, dans le lot ; S7 « faite » =
`sheetId` + passage + date <= aujourd'hui ; S8 repli explicite avec exercices
du bloc.

## 10. Lots

| Lot | Contenu | Critère de fin |
|---|---|---|
| C1 | Scénarios BDD du § 8 + steps (rouge vu) | `.feature` générés, tests rouges constatés |
| C2 | Domaine (TDD) : `SheetSuggestion`, `suggestSheet`, `SessionPlan.sheet`, `SuggestSession` (dépôt, passages, `Clock`, `validatedByAll`, remplacement des exercices), test de couverture du catalogue, `scripts/generate.sh` | tests unitaires verts, table du § 3 couverte |
| C3 | Présentation : carte, note, repli, callbacks de `SessionPlanView`, page, `AppRoutes.recordFromSuggestion`, câblage `/session`, l10n fr / en, Widgetbook | scénarios BDD verts, `check_widgetbook` vert |
| C4 | S6 : `group` sur `AppRoutes.guide`, `RunKey`, `RunSheetSessions`, `_runKey`, `_guideKey` ; **non reportable** (le guide puis la saisie sont la fonction principale) | scénario « guide depuis la suggestion » vert |
| C5 | Docs (`architecture.md`, renvois dans ADR 0007 et ADR 0008, `guide-animateur.md`, roadmap), `scripts/check.sh --full`, revues `architecte-fsd` + `testeur-bdd` | tout vert, revues sans réserve bloquante |

## 11. Risques

- **Séance ≠ exercices** (S3) : résolu par le remplacement des exercices par
  ceux de la séance et la note sur la tête ; reste le risque de lire la tête
  comme omise : texte de la note à valider à la relecture.
- **Historique sans `sheetId` ou sans passage** : un groupe repart de la partie
  contenant sa tête ; documenté.
- **`validatedByAll` sur un groupe hétérogène** : un élève très en retard rend
  « sans objet » rare ; voulu (la séance sert encore à lui).
- **Champ ajouté à `SessionPlan`** : fixtures de test à revoir ; champ
  facultatif (défaut nul).
- **Blocs sans séance** : cas nominal ; le repli ne doit jamais lever ni
  laisser l'animateur sans action.
- **`RunKey.group`** : deux guidages de même séance mais de groupes différents
  ne partagent plus leur état (voulu) ; `maxRunning` inchangé.
- **Doublon de logique** avec `resultsRecallBlock` (sens inverse) : deux
  fonctions pures dans leur couche, sans dépendance croisée.

## 12. Écarts à la livraison

- `suggestSheet` a 7 entrées : `planExercises` (sans usage) est supprimé ;
  `exerciseNumbers` contient tous les numéros de la séance, dans son ordre.
- `kind` : `coversHead` (à faire, contient la tête), `nextPending` (à faire,
  ne la contient pas), `repeat` (tout fait) ; `lastGivenOn` n'est renseigné
  que pour `repeat`. Si aucune séance ne contient la tête, la fonction rend
  `null`.
- `suggestSheet` n'est pas appelé quand `planSession` échoue (`noStudents`,
  `nothingToTeach`).
- Échec du catalogue de séances : testé en unitaire (`InvariantViolation`),
  pas en BDD.
- `TrackingWorld` fige l'horloge au 2026-10-12, comme `UiWorld`.
- Carte : le titre de la séance n'est pas répété quand il est celui de la
  notion principale (carte précédente) ; le libellé de partie réutilise
  `sheetPartLabel`.
- `AppRoutes.presentation` porte aussi `group`, pour que l'aller-retour par
  la présentation ne perde pas le groupe du guide.
- Scénario « planifiée » : l'assertion porte sur le titre prérempli du
  planificateur (le champ séance y apparaît deux fois à l'écran) ; scénario
  « guide » : deux groupes, la suggestion est faite pour le groupe adultes
  pour que la saisie ne retombe pas sur le premier groupe par défaut.
- Widgetbook : deux cas de `SessionPlanView` (avec et sans séance du
  catalogue).

