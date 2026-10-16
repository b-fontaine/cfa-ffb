# Plan d'exécution : accueil « Aujourd'hui » et bilan de fin de séance (lot U7)

Statut : **livré le 2026-10-15** (lots I1 à I8 ; revues `architecte-fsd` et
`testeur-bdd` et `check.sh --full` à faire par l'animateur, voir § 12). Plan
de conception d'origine ci-dessous. Sources : [roadmap](roadmap.md)
(U7, lots 6 et 8), [ux/plan-ux-proposition.md](ux/plan-ux-proposition.md) (U7,
§ 4, décisions Q1 à Q8 tranchées), [ux/recommandations-design.md](ux/recommandations-design.md)
(R8, § 4.4, R16), [ux/audit-ux-ui.md](ux/audit-ux-ui.md) (accueil),
[navigation-plan.md](navigation-plan.md) (bandeau de sauvegarde posé par le
routeur), ADR 0004, 0007, 0009, 0010, 0011, [architecture](architecture.md),
[testing](testing.md), [design-system](design-system.md).

Pas d'ADR : aucune décision structurante (aucune migration, aucune dépendance,
pas de nouvelle couche). Les décisions de ce lot vivent dans ce plan. Les points
qui relèvent du produit sont listés au § 11 pour l'animateur `[U]` et ne sont
pas tranchés silencieusement : chacun a une proposition par défaut, qui est ce
que le plan suppose.

## 1. Constats sur le code

- `pages/home/HomePage` est statique (carte « Deux publics », bouton
  « Planifier une séance ») ; `banner` est déjà fourni par `app/router.dart`
  (`BackupReminderCubit` + `BackupReminderBanner`). À conserver tel quel, au-dessus
  du contenu.
- `ListSessions` (`features/plan_session`) rend déjà les séances planifiées
  triées par date, avec `Group?` et `recordId` (lien dérivé : saisie du même
  groupe le même jour, ADR 0007). Il ne filtre pas et ne connaît pas l'horloge.
- `RunSheetSessions` (`@lazySingleton`, **en mémoire**) garde au plus 4
  `RunSheetCubit` par `RunKey` (fiche, public, séance planifiée, groupe) ;
  `RunSheetState.hasProgress` dit s'il y a de la progression ; `plan` porte la
  fiche (`SheetOption`) et la séance planifiée résolue. Rien n'est persisté : un
  rechargement de la page web vide le registre (l'adresse `?step=` reste, elle,
  valide).
- Fin de séance : `SheetGuidePage.onFinish` → `RunSheetCubit.finish()` (remise à
  zéro) puis le routeur fait `context.go(origin())` et `sessions.release(key)`.
  Aucun écran de bilan.
- `RunRecordChoice` (groupe, date, absents) est retenu par `recordChosen` à deux
  endroits (routeur `/record/new` et `app/record_sheet.dart`, U5) à partir d'un
  `OpenedRecord` qui **porte l'identifiant de la saisie** (`opened.id`) :
  l'identifiant n'est simplement pas conservé aujourd'hui.
- Alertes : `StudentProgress.activeAlerts` (entités, déjà masquées pour les
  exercices acquis) ; `ExerciseResult.alert` (`attention` / `persistent`),
  `consecutiveFailures`, `validatedOn` ; seuils lus dans `RulesConfig`
  (fabrique get_it sur `RulesStore`, ADR 0012 : ne jamais conserver une instance
  dans un singleton).
- Suggestion : `SuggestSession(groupId, expectedStudents)` rend un `SessionPlan`
  dont `sheet` est la `SheetSuggestion` (ADR 0009 : « faite » = saisie avec
  séance **et** au moins un passage, datée au plus tard aujourd'hui). Une fois la
  saisie de la séance donnée, la règle propose donc la partie suivante sans rien
  changer. `SuggestedSessionBloc` charge aussi les fiches d'exercices : trop
  lourd pour un bilan.
- Planification : `PlanSession(title, date, audience, sheetId, groupId)` fait
  déjà les contrôles (groupe inconnu, date hors saison → `seasonOutsidePeriod`).
  Le titre vient de l'interface (`sheetFullTitle` côté planificateur).
- `BilliardBall(kind: BallKind.black, label: '8')` existe : la bille n° 8 ne
  coûte aucune dépendance. `BallColors.cloth` existe (motif de tapis possible).
- Plusieurs scénarios existants affirment le titre actuel (`Prepare a session`) :
  `localization.feature:5`, `navigation.feature:41`, `screen_navigation.feature:103,107`
  et leurs `_test.dart` (`screen_navigation_test.dart:161-183`,
  `localization_test.dart:17`). `iSeeText` utilise `findsOneWidget` : un titre
  « Today » ferait doublon avec l'étiquette de navigation « Today ». Ces
  scénarios sont **adaptés** pour viser un texte unique de l'accueil vide
  (« Plan the next session »).

## 2. Décisions

### 2.1 Quelles données l'accueil agrège, et d'où

| Bloc d'écran | Donnée | Source (cas d'usage, slice) |
|--------------|--------|-----------------------------|
| Séance en cours (1 carte, + autres en lignes) | séances guidées avec progression | `RunSheetSessions.snapshot()` via `RunningSessionsCubit` (`features/run_sheet`) |
| Prochaine séance (1 carte) | séances planifiées datées, groupe, lien « saisie » | `GetUpcomingSessions` (`features/plan_session`, s'appuie sur `ListSessions`) |
| À noter (≤ 3 lignes) | séances passées sans saisie | idem |
| À surveiller (≤ 5 lignes) | élèves avec alerte active | `ListWatchedStudents` (`features/track_progress`) |
| 7 derniers jours | passages, validations, séances données | `GetWeekSummary` (`features/track_progress`) |
| Sauvegarde | rappel | déjà livré (U6), inchangé, via `banner` |

Chaque bloc a **son cubit, ses états** (`loading / ready / failure`) : une
section en échec affiche `ErrorView` compact avec « Réessayer » sans bloquer les
autres. La page compose ; elle ne calcule rien (R8).

### 2.2 Use cases de domaine et slices FSD (pas d'import latéral)

La règle « imports vers le bas, jamais entre slices d'une même couche » interdit
à une feature d'appeler `ListSessions` ou `SuggestSession` d'une autre. Chaque
règle vit donc dans la slice qui possède le concept, et **les pages composent**
(comme `StudentSheetPage` compose `StudentSheetBloc` et `StudentRecallBloc`).

- **`entities/exercise_result/domain/watch_list.dart`** (nouveau, Dart pur) :
  `watchedStudents(...)` partagé par l'accueil et le bilan : un `WatchedStudent`
  par élève (exercice le plus alarmant : `persistent` avant `attention`, puis
  échecs consécutifs décroissants, puis ordre du catalogue ; `otherAlerts` =
  nombre d'autres alertes). Évite de dupliquer la dérivation dans deux features.
- **`features/plan_session`** : `GetUpcomingSessions` (horloge injectée) +
  fonction pure `upcomingOf(summaries, today)` → `UpcomingSessions {next,
  sameDayOthers, toRecord, groupNames}` ; `UpcomingSessionsCubit` ;
  `PlanNextSessionCubit` (appelle `PlanSession`, états `idle / planning /
  planned(Session) / failure(motif)`).
- **`features/track_progress`** : `ListWatchedStudents` (charge `AttemptRepository.all()`
  une fois, dérive `StudentProgress` par élève, appelle `watchedStudents`),
  `GetWeekSummary` (horloge injectée) + fonction pure `weekSummary`, et leurs
  deux cubits.
- **`features/run_sheet`** : `RunSheetSessions.snapshot()` (lecture seule, liste
  de `RunningSession {key, step, stepCount, phase, sheetTitle, part, partCount,
  plannedGroupId, plannedDate}` pour les cubits `status == ready` avec
  `hasProgress`, du plus récent au plus ancien) ; `RunningSessionsCubit`
  (snapshot à la création + `abandon(key)` → `release`). Pas de flux : l'accueil
  est reconstruit à chaque navigation (`context.go`), le snapshot suffit.
- **`features/review_session`** (nouvelle slice, domaine = entités seulement) :
  `GetSessionReview(sessionId)` → `SessionReview`, `SessionReviewBloc`,
  `SessionReviewView`.
- **`features/suggest_session`** : `SuggestNextSheet(groupId, present)` (appelle
  `SuggestSession`, ne charge pas les fiches d'exercices) → `NextSheet
  {sheet: SheetSuggestion?, audience}` ; `NextSheetCubit`. Aucune modification de
  `SuggestSession`, donc règle du lot 8 / ADR 0009 inchangée.
- **`pages/home`** compose `UpcomingSessionsCubit`, `RunningSessionsCubit`,
  `WatchedStudentsCubit`, `WeekSummaryCubit` + `banner`. La jointure
  « en cours ↔ nom du groupe » (clé du guide → `groupNames`) est faite par la
  page, à partir de données déjà chargées.
- **`pages/session_review`** (nouvelle) compose `SessionReviewBloc` +
  `NextSheetCubit` + `PlanNextSessionCubit` ; elle déclenche `NextSheetCubit`
  quand le bilan est prêt (groupe et présents connus).
- **`shared/ui/now_card.dart`** : `NowCard` sans dépendance métier.
- **`app`** : routes, câblage des callbacks, `RunRecordChoice.recordId`.

### 2.3 Définitions exactes

Toutes les dates raisonnent **au jour près** (`dateOnly`, fuseau local, horloge
injectée `Clock.today()`), comme la planification.

- **Séance en cours** : un `RunSheetCubit` de `RunSheetSessions` dont
  `status == ready` et `hasProgress` (étape après la première, compteurs, critères,
  score). Le minuteur seul n'en fait pas une. Indépendant de la date et de
  l'existence d'une séance planifiée : un guide lancé depuis le catalogue ou la
  suggestion est « en cours » aussi. Une seule carte (la plus récemment
  utilisée) ; les autres (au plus 3, plafond de `maxRunning`) sont des lignes
  « Autre séance commencée : <titre> · Reprendre ». Reprendre =
  `AppRoutes.guide(..., step: state.step)` (pas de proposition « reprendre /
  recommencer » redondante).
- **Prochaine séance** : parmi les séances planifiées **sans saisie**
  (`recordId == null`), la première par (date, ordre de planification) avec
  `date >= aujourd'hui`. Une séance d'aujourd'hui déjà saisie est « faite » et
  n'est plus proposée. R8 disait « date ≥ aujourd'hui » : la précision « sans
  saisie » évite d'inviter à lancer une séance déjà donnée. D'autres séances le
  même jour : une ligne « + 1 autre séance ce jour-là » vers « Planifiées ».
- **À noter** : séances planifiées avec groupe, sans saisie, datées des 7 jours
  qui précèdent aujourd'hui (borne basse incluse), plus récentes d'abord, au plus
  3, action « Noter les résultats » (`recordFromPlan`). Au-delà de 7 jours ou
  sans groupe : seulement dans « Planifiées ».
- **Semaine** : **7 jours glissants, aujourd'hui inclus** (de J-6 à J). Justifié :
  la semaine civile dépend de la locale (lundi fr, dimanche en) et se vide chaque
  lundi, jour où l'animateur ouvre justement l'application pour préparer la
  suite ; avec une séance par semaine, 7 jours glissants contiennent toujours la
  dernière séance donnée. Libellé : « 7 derniers jours ». Contenu : passages
  saisis (`ExerciseAttempt.date` dans la fenêtre), validations (`validatedOn`
  dans la fenêtre, par élève et exercice), séances données (`SessionRecord.date`
  dans la fenêtre). La date d'un passage est celle de la séance, pas de la
  saisie (limite déjà documentée pour le rappel de sauvegarde).
- **Alertes** : tous les élèves du club (`StudentRepository.all()`) avec au moins
  une alerte active. **Une ligne par élève** (exercice le plus alarmant,
  « +N autres » si besoin). Tri : niveau persistant d'abord, échecs consécutifs
  décroissants, identifiant de l'élève (comparateur unique
  `compareWatched`, entité `exercise_result`, partagé avec le bilan). Les ex
  aequo suivent l'ordre des identifiants, **pas l'ordre alphabétique** des prénoms.
  **Limite d'affichage : 5**, puis « Voir tous les élèves
  (N) » vers `/students`. Ligne = `StudentChip` + exercice + « n échecs de
  suite » + niveau en texte (jamais la couleur seule, jamais de rouge d'état :
  `AppAlert` attention, ADR 0010) ; tape → fiche élève. Les alertes de **groupe**
  (R8 : « 4 élèves sur 8 ») étaient reportées : **livrées avec U9** (carte
  « Alertes de groupe », trois au plus, [plan U9](fiche-eleve-plan.md)).
- **États vides** : (a) ni séance ni élève : bille n° 8, message d'accueil,
  « Planifier la prochaine séance », « Voir la suggestion pour un groupe » et
  « Ajouter des élèves » ; (b) élèves mais aucune séance à venir : carte
  « Aucune séance planifiée » avec les deux premières actions ; (c) aucune
  alerte : une ligne calme « Aucun élève à surveiller » ; (d) semaine à zéro :
  « Aucun passage saisi ces 7 derniers jours ». La page n'est jamais vide.
- **Séance sans fiche du catalogue** : pas de « Préparer » ni « Lancer » ;
  action unique « Ouvrir dans Planifiées ». **Groupe disparu**
  (`groupUnavailable`) : mention d'attention, « Lancer » reste possible.
- **« Préparer »** = `AppRoutes.sheet(sheetId, audience, origin:
  SheetOrigin.today)` depuis U8 : le retour mène à « Aujourd'hui » (libellé
  « Aujourd'hui »). En U7 c'était `fromPlanner: true` (retour à « Planifiées »,
  comportement de la ligne planifiée), voir U-12 ci-dessous : **soldé par U8**.
  **« Lancer »** = `AppRoutes.guide(sheetId, audience, session: <id>, from:
  SheetOrigin.today)` depuis U4 ; « Reprendre » porte le même `from=today` : le
  retour du guide (flèche, ou « Terminer » sans saisie) mène à « Aujourd'hui »
  et non plus à « Planifiées » (report U-9 **soldé par U4**, [ADR
  0015](adr/0015-guide-mener-route-modes-origine.md)).

### 2.4 « Terminer » mène au bilan sans casser reprise ni liens profonds

- **Route** : nouvelle page **`/record/:sessionId/review`** (dans le
  `ShellRoute`, `AppRoutes.review(SessionId)`). Le bilan est une vue d'une
  **saisie persistée** : tout est relu depuis les dépôts, donc il survit à un
  rechargement, se partage par adresse et ne dépend d'aucun état en mémoire.
  Alternatives écartées : feuille basse du guide (état du guide détruit juste
  après `release`, perdue au rechargement, non adressable) ; route enfant du
  guide (porterait une `RunKey` dont l'état vient d'être libéré). Sélection de
  la navigation : « Résultats » (c'est le bilan d'une saisie).
- **Identifiant de saisie** : `RunRecordChoice` gagne `recordId`
  (`recordChosen(recordId:, ...)`, appelé aux deux endroits existants avec
  `opened.id`). `SheetGuidePage.onFinish` devient `ValueChanged<SessionId?>` :
  la page lit `state.recordChoice?.recordId` **avant** `finish()` (qui remet
  l'état à zéro) et le transmet.
- **Câblage (`app/router.dart`)** : recordId présent → `context.go(
  AppRoutes.review(id))`, puis `sessions.release(key)` (ordre actuel conservé) ;
  absent (aucune saisie ouverte depuis ce guide) → comportement actuel
  inchangé (`context.go(origin())`). Pas de bilan « fantôme » sans saisie
  (voir U-6).
- **Reprise** : rien ne change tant que l'animateur n'a pas confirmé
  « Terminer » ; le guide reste libérable/évincable comme aujourd'hui. Le bilan
  n'est pas un état du guide : le retour navigateur depuis le bilan retombe sur
  l'adresse du guide, qui recrée un cubit neuf (étape de l'adresse, compteurs à
  zéro) ; un second « Terminer » rouvre le même bilan (idempotent).
- **Liens profonds** : identifiant inconnu → `MissingPageView` avec retour à
  « Aujourd'hui » (même traitement que les autres pages). Les adresses du guide
  (`?step=`, `session`, `group`, `audience`) sont inchangées ; la présentation
  plein écran aussi.
- **Boîte de confirmation** : le texte de `guideFinishBody` annonce le bilan.

### 2.5 Contenu du bilan (`SessionReview`)

Calculé par `GetSessionReview(sessionId)` à partir des seuls dépôts d'entités
(saisie, passages, acquis, élèves, groupe, saison, séances planifiées,
catalogue) ; fonction pure `reviewSession(...)` testée sans dépôt.

1. **En-tête** : titre de la séance du catalogue (`SheetOption` : « Quantité
   demi-bille, séance 2/2 », repli neutre si inconnue), groupe, date, nombre de
   présents.
2. **Passages saisis** : total, puis par exercice (titre, passages, réussis au
   regard du taux requis). Un résumé par exercice, pas la grille `PassDots`.
3. **Validations du jour** : exercices **nouvellement validés par cette
   saisie**, par élève. Calcul exact : validés après (tous les passages) moins
   validés avant (sans les passages de cette saisie), acquis compris. Valable
   quel que soit `passesRequired` (réglage lot 9) ; un exercice validé à une
   séance précédente n'est jamais listé.
4. **À surveiller** : élèves **présents** avec alerte active (`watchedStudents`).
5. **Non notés** : présents sans aucun passage dans cette saisie.
6. **Séance suivante** (§ 2.6).
7. Actions : « Planifier », « Voir la suggestion » (`/session`), « Voir la
   saisie » (`recordSession(id)`), « Retour à Aujourd'hui ». Titre de page :
   « Bilan de la séance ».

Saisie **sans aucun passage** : le bilan l'indique, propose « Saisir les
résultats » (`recordSession(id)`) et **n'affiche pas** la séance suivante : tant
que la saisie n'a pas de passage, la règle du lot 8 ne la compte pas comme faite
et reproposerait la même séance.

### 2.6 Séance suivante et « Planifier »

- **Proposition** : `SuggestNextSheet(groupId, present)` = la règle du lot 8
  telle quelle (exercice de tête décide, « faite » = saisie avec séance et
  passage, repli explicite pour une notion sans séance : « Aucune séance du
  catalogue pour cette notion », jamais de séance inventée). Si tout est fait :
  la séance redonnée avec la date de la dernière fois (`lastGivenOn`), comme
  `SuggestedSessionPage`. Les `expectedStudents` sont les présents de la saisie.
- **Date proposée** : le même jour de la semaine que la séance donnée, la
  semaine suivante (`record.date + 7 j`), avancée par pas de 7 jours jusqu'à être
  **strictement après aujourd'hui**. Fonction pure `nextSameWeekday`. Affichée
  « Jeudi 22 octobre » avec « Modifier la date » (sélecteur, bornes : demain,
  fin de saison).
- **Création** : « Planifier » → `PlanNextSessionCubit` → `PlanSession(title:
  sheetFullTitle, date, audience: groupe, sheetId, groupId)` : la séance
  planifiée est **datée et liée au groupe** (report du lot 8 réalisé). Succès :
  la carte devient « Planifiée le jeudi 22 oct. · Voir dans Planifiées »
  (`AppRoutes.planner`) et le bouton disparaît.
- **Idempotence** : `GetSessionReview` repère une séance planifiée du même
  groupe, de même fiche, datée d'après aujourd'hui : la carte affiche alors
  « Déjà planifiée le … » au lieu du bouton (pas de doublon sur double tape ni à
  la réouverture du bilan). Un faux négatif (même fiche, autre date) reste
  possible et sans gravité.
- **Échecs** : `seasonOutsidePeriod` (date après la fin de saison) →
  `AppAlert` attention « La saison se termine avant cette date » + « Ouvrir le
  planificateur » (`AppRoutes.plan(sheet, audience)`), qui présélectionne la
  séance ; groupe disparu ou notion sans fiche → seul « Ouvrir le planificateur »
  (sans présélection pour une notion sans fiche). Aucun rouge d'état.

## 3. Conception de l'écran « Aujourd'hui »

Ordre (de haut en bas) : bandeau de sauvegarde (`banner`, inchangé) ; en-tête
(bille n° 8, « Aujourd'hui », date du jour, motif de tapis) ; « En cours » ;
« Prochaine séance » ; « À noter » ; « À surveiller » ; « 7 derniers jours ».
Jamais plus de deux `NowCard` (en cours, prochaine). Cibles ≥ 48 dp,
`ResponsiveBody` (une colonne ; deux colonnes ≥ 840 dp : cartes à gauche,
alertes et semaine à droite), pas de rouge comme état.

`NowCard` (`shared/ui`) : étiquette d'état (texte + icône : « En cours » /
« Prochaine »), titre, lignes de méta, action principale (`FilledButton`),
action secondaire (`OutlinedButton`) ; `emphasis` repris de `SectionCard`
(`high` pour « en cours », bord `secondary` bleu-tapis, ADR 0010). Aucune entité
importée.

Décor : `BilliardBall(kind: black, label: '8')` dans l'en-tête et l'état vide
(aucun coût) ; `ClothPattern` (`shared/ui`, ~40 lignes, `CustomPainter`, grille
8 × 4 en `BallColors.cloth` à 6 %, `ExcludeSemantics`) en dernier lot, retirable
sans effet sur le reste. Aucune dépendance.

## 4. Reportés (documentés, rien de stubbé)

- ~~Alertes de **groupe** (« 4 élèves sur 8 »)~~ : **soldé avec U9** (carte « Alertes de groupe » sur « Aujourd'hui », grille du groupe ; seuil `groupFailureSharePercent`).
- ~~Origine « Aujourd'hui » du détail d'une séance (retour direct) : U8.~~ **Soldé avec U8** (`SheetOrigin.today`, adresse `?from=today`).
- Rappels natifs (veille de séance, sauvegarde) : H4, lot 22.
- Persistance de la séance en cours au rechargement : non faite (U-5).
- Bilan d'une séance **sans** saisie, entrée du bilan depuis l'historique : § 11.
- Motif de tapis en mode présentation : U3 (le composant `ClothPattern` y sera
  réutilisé).

## 5. Fichiers à créer / modifier par couche

| Couche | Créer | Modifier |
|--------|-------|----------|
| `shared` | `ui/now_card.dart`, `ui/cloth_pattern.dart`, clés ARB fr/en (`home*`, `review*`, `nowCard*`) | `l10n/app_fr.arb`, `app_en.arb` (retrait de `homeAudiencesTitle` et `homeSubtitle` si inutilisés ; `guideFinishBody`) |
| `entities` | `exercise_result/domain/watch_list.dart` (`WatchedStudent`, `watchedStudents`) | rien d'autre |
| `features/plan_session` | `domain/upcoming_sessions.dart` (+ `upcomingOf`), `domain/get_upcoming_sessions.dart`, `presentation/bloc/upcoming_sessions_cubit.dart`, `plan_next_session_cubit.dart`, `ui/upcoming_cards.dart` | aucun cas d'usage existant |
| `features/track_progress` | `domain/list_watched_students.dart`, `domain/week_summary.dart`, `domain/get_week_summary.dart`, `presentation/bloc/watched_students_cubit.dart`, `week_summary_cubit.dart`, `ui/watched_students_card.dart`, `ui/week_summary_card.dart` | |
| `features/run_sheet` | `domain/running_session.dart`, `presentation/bloc/running_sessions_cubit.dart`, `ui/running_session_card.dart` | `run_sheet_sessions.dart` (`snapshot()`), `run_sheet_state.dart` (`RunRecordChoice.recordId`), `run_sheet_cubit.dart` (`recordChosen`) |
| `features/suggest_session` | `domain/suggest_next_sheet.dart`, `presentation/bloc/next_sheet_cubit.dart`, `ui/next_sheet_card.dart` | |
| `features/review_session` | `domain/session_review.dart`, `domain/review_session.dart` (pure), `domain/next_session_date.dart`, `domain/get_session_review.dart`, `presentation/bloc/session_review_bloc.dart`, `ui/session_review_view.dart` | |
| `pages` | `session_review/presentation/session_review_page.dart` | `home/presentation/home_page.dart` (refonte, `onOpenPlanner` et `banner` conservés), `sheet_guide/.../sheet_guide_page.dart` (`onFinish` reçoit l'identifiant de saisie) |
| `app` | | `router.dart` (`AppRoutes.review`, `reviewSegment`, route, providers de l'accueil, `onFinish`), `record_sheet.dart` et routeur `/record/new` (`recordChosen(recordId:)`), `shell.dart` (`indexOf` inchangé : `/record/…` = Résultats, couvert par un test), `di/injection.config.dart` (build_runner) |
| Widgetbook | use cases `NowCard` (états, thèmes), bilan, accueil vide | |
| docs | | `roadmap.md` (U7 livré), `navigation-plan.md` (reports U7 réalisés), `architecture.md` (slices, route), `design-system.md` (`NowCard`, `ClothPattern`), `testing.md`, `ux/plan-ux-proposition.md`, `suggestion-catalogue-plan.md` (report « Planifier direct » réalisé), `README.md` d'index |

Fichiers générés (freezed, `injection.config.dart`, l10n) : uniquement par
build_runner / `gen-l10n`.

## 6. Lots d'implémentation (ordre ; chaque lot : BDD rouge constaté, puis TDD vert)

1. **I1 Fondations UI** : `NowCard` (test de widget, cibles ≥ 48 dp, thèmes
   clair et sombre, contraste), clés ARB, Widgetbook. Aucun écran.
2. **I2 Règles pures** : `watchedStudents` (entités), `upcomingOf`,
   `weekSummary`, `nextSameWeekday` (tests unitaires d'abord, horloge injectée).
3. **I3 Accueil, données** : `GetUpcomingSessions`, `ListWatchedStudents`,
   `GetWeekSummary`, `RunSheetSessions.snapshot`, cubits ; tests sur les dépôts
   in-memory ; mesure sur 60 élèves.
4. **I4 Accueil, écran** : `HomePage` recomposée, routeur, `banner` conservé ;
   `home.feature` vert ; adaptation des scénarios « Prepare a session ».
5. **I5 Bilan, données et écran** : `GetSessionReview`, bloc, vue, page, route
   `/record/:id/review`, `AppRoutes.review` ; `session_review.feature` (volet
   contenu).
6. **I6 Séance suivante et « Planifier »** : `SuggestNextSheet`,
   `NextSheetCubit`, `PlanNextSessionCubit`, carte, idempotence, échecs.
7. **I7 « Terminer » vers le bilan** : `RunRecordChoice.recordId`, `onFinish`,
   routeur, texte de confirmation ; scénarios de `session_guide.feature` ;
   libération du guide vérifiée.
8. **I8 Décor et finitions** : bille n° 8, `ClothPattern`, deux colonnes
   ≥ 840 dp, vérification Playwright web (arbre sémantique, captures hors
   dépôt), `check.sh --full`, documents (§ 5).

Revue indépendante en fin de lot I4 et I7 : `architecte-fsd` + `testeur-bdd`
(contexte séparé).

## 7. Scénarios BDD à écrire d'abord

### `home.feature` (nouveau ; accueil)

1. Without any session or student, the home offers to plan, see the suggestion
   and add students
2. With students but no planned session, the home shows an empty next-session
   card with Plan and Suggestion actions
3. The next planned session is shown with its date, group and sheet, and Prepare
   and Launch
4. A session planned for today without results is the next session
5. A session planned for today with results already recorded is not proposed
6. Only the first session of a day is shown, with a link to the others
7. A past planned session without results in the last seven days is offered to
   be noted
8. A planned session without a catalogue sheet offers to open it in Planned
   instead of Prepare and Launch
9. A started guided session is shown with the current step and Resume
10. Resume opens the guide at the saved step
11. A started session and a next session are both shown, and no more than two
    cards
12. A guided session started from the suggestion appears without a planned
    session
13. A started session can be abandoned after a confirmation
14. A student with an active alert is listed with the exercise and the
    consecutive failures
15. Persistent alerts come before attention alerts
16. At most five students to watch are listed, with a link to all students
17. A validated exercise never shows an alert
18. With no alert, the home says nobody needs watching
19. The last seven days count passes, validations and sessions given
20. A pass eight days old is not counted
21. The backup reminder is kept above the cards
22. Launch from the home opens the guide of the planned session
23. Prepare from the home opens the catalogue sheet
24. The home is titled « Aujourd'hui » on a French device and every action is
    at least 48 dp
25. Failure to load one section shows a retry without hiding the others

### `session_guide.feature` (adapté + ajouts)

26. Finishing a guided session with recorded results opens the session summary
27. Finishing a guided session without recorded results returns where it came
    from, as before
28. The finished guided session is released: the home no longer offers to
    resume it
29. The confirmation announces the summary
30. Back from the summary reopens the guide address with a fresh session

### `session_review.feature` (nouveau ; bilan)

31. The summary names the sheet, group, date and number of present students
32. The summary lists the passes entered per exercise with the successful ones
33. An exercise validated by this session is listed with the student
34. An exercise validated in an earlier session is not listed
35. The validation count follows the passes required setting
36. Present students without any pass are named
37. Present students with an active alert are listed, absent ones are not
38. The summary proposes the next catalogue session of the group (the part after
    the one given)
39. When every part is given, the same session is proposed with the date of the
    last time
40. A notion without catalogue session shows the explicit fallback and Plan
    opens the planner
41. Plan creates a dated session planned for the group
42. The proposed date is the same weekday the following week
43. A date in the past is moved to the next same weekday after today
44. A session already planned for the group is shown instead of the Plan button
45. A date after the end of the season is refused with a message and the
    planner link
46. Changing the proposed date is reflected in the planned session
47. A record without any pass shows no next session and offers to enter results
48. The summary opens by address and after a reload
49. An unknown summary address is a missing page that leads to Today
50. The summary is shown in French on a French device
51. Back to Today returns to the home, where the planned session now appears

### Existants adaptés

`localization.feature`, `navigation.feature` (« The error page leads back to the
home screen »), `screen_navigation.feature` (deux scénarios « leads home »), leurs
`_test.dart` : remplacer `Prepare a session` par un texte unique de l'accueil
vide. `navigation.feature` : l'étiquette « Today » reste dans les cinq
destinations. `design_system.feature` : inchangé.

### Tests unitaires et de widget (écrits avant le code)

`watchedStudents` (ordre, acquis masqués) ; `upcomingOf` (date égale, saisie
présente, même jour, sans fiche, groupe disparu, à noter sur 7 jours) ;
`weekSummary` (bornes J-6 et J-7) ; `reviewSession` (validé avant / après,
`passesRequired` 2 et 5, élèves sans passage) ; `nextSameWeekday` (passé,
aujourd'hui, fin de saison) ; `GetUpcomingSessions` et `GetWeekSummary` (horloge
fixe) ; `RunSheetSessions.snapshot` (ordre, états ignorés, évincés) ; chaque
cubit (loading / ready / failure) ; `NowCard` ; `shell_routes_test`
(`/record/x/review` sélectionne « Résultats ») ; `check_architecture` (aucune
nouvelle arête latérale).

## 8. Internationalisation et accessibilité

Clés fr et en identiques ; dates par `intl` selon la locale (« jeudi 22
octobre », libellés relatifs « aujourd'hui », « demain ») ; pluriels ICU pour
passages, validations, séances ; aucun libellé en dur. Chaque `NowCard` est un
groupe sémantique (état + titre + méta) ; les niveaux d'alerte sont en texte ;
le décor (bille 8, motif) est exclu de la sémantique.

## 9. Risques

| Risque | Parade |
|--------|--------|
| Séance en cours **perdue au rechargement** (registre en mémoire) | Comportement actuel assumé et documenté ; l'adresse `?step=` reste valide ; U-5 |
| Séances commencées **jamais terminées** restent « en cours » | « Abandonner » avec confirmation ; plafond de 4 ; limite d'affichage |
| Noms d'élèves mineurs sur un accueil que les élèves peuvent voir | U-4 ; la vue « à montrer à l'élève » (U9) est le contournement prévu |
| Temps de chargement de l'accueil (4 cubits, tous les passages) | Une seule lecture `AttemptRepository.all()` ; sections indépendantes ; mesure sur 60 élèves au lot I3 ; pas de cache tant que non mesuré |
| Violation FSD par composition (page vers 4 features) | Les pages composent ; `check_architecture` + revue `architecte-fsd` |
| Doublon de planification (double tape, réouverture) | Idempotence § 2.6 + état `planning` désactivant le bouton |
| Date proposée hors saison / groupe sorti | Contrôles du cas d'usage existant, messages explicites, repli planificateur |
| Titre « Aujourd'hui » dupliqué avec l'étiquette de navigation (`findsOneWidget`) | Scénarios visant un texte unique |
| Retour navigateur depuis le bilan recrée un guide | Documenté (§ 2.4) ; sans perte de données |
| Régression des scénarios existants sur « Prepare a session » | Liste § 7 ; adaptés dans I4, avant tout autre changement |
| `RunRecordChoice` (typedef) et `onFinish` changent de signature | Changement local à 3 fichiers + tests ; régénération build_runner |
| Vérification de `check.sh` sur `docs/knowledge` modifié par une autre session | Ne pas toucher `docs/knowledge` ; ne lancer que les garde-fous de `app/` si `sync_*` échoue pour cette raison |

## 10. Définition de « terminé » du lot

`scripts/check.sh --full` vert ; les 51 scénarios ci-dessus verts (rouge
constaté avant le code, consigné) ; aucune chaîne en dur ; aucun TODO, `skip`,
stub ; documents du § 5 à jour (roadmap : U7 livré, report « Planifier direct »
du lot 8 coché) ; vérification en navigateur (Playwright, captures hors dépôt) :
accueil vide, accueil rempli, bilan, terminaison depuis le guide.

## 11. Points qui demandent une décision `[U]` de l'animateur

Le plan suppose la proposition par défaut ; aucune n'est tranchée.

- **U-1 Semaine** : 7 jours glissants (proposé) ou semaine civile lundi à dimanche.
- **U-2 Date de la séance suivante** : même jour de semaine +7 j (proposé), +14 j
  (groupes à quinzaine), ou laissée vide à choisir.
- **U-3 Modifier la date dans le bilan** : sélecteur de date (proposé) ou date
  fixe, à ajuster ensuite dans « Planifiées ».
- **U-4 Noms d'élèves sur l'accueil** : alertes visibles (proposé, décision R8)
  ou masquées derrière « Voir les élèves à surveiller » quand la tablette peut
  être vue des élèves.
- **U-5 Séance en cours après rechargement ou fermeture de l'application** :
  perdue (proposé, aucun changement de schéma) ou persistée (compteurs et étape :
  schéma drift v8 + sauvegarde).
- **U-6 « Terminer » sans aucune saisie** : retour inchangé sans bilan (proposé)
  ou bilan « aucun résultat » qui invite à saisir.
- **U-7 « À noter »** : séances passées sans saisie sur 7 jours listées sur
  l'accueil (proposé) ou seulement dans « Planifiées ».
- **U-8 « Abandonner »** une séance commencée depuis l'accueil : proposé, avec
  confirmation.
- **U-9 Bilan depuis l'historique** : bouton « Voir le bilan » sur une séance
  saisie (une ligne de câblage ; non demandé, donc non inclus par défaut).
- **U-10 Décor** : bille n° 8 (proposé) ; motif de tapis en en-tête (proposé) ou
  reporté à U3.
- **U-11 Limite d'alertes** : 5 élèves visibles sur l'accueil (proposé), 3, ou
  tous.
- **U-12 « Préparer »** : retour vers « Planifiées » (proposé, comportement
  actuel) en attendant U8, ou retour direct à « Aujourd'hui » dès U7 (un
  paramètre d'origine et un libellé de plus dans le détail). **Soldé par U8
  (2026-10-16)** : le paramètre d'adresse `from` prend `catalogue`, `planner` ou
  `today` ; « Préparer » depuis « Aujourd'hui » revient à « Aujourd'hui ». Le
  retour du guide lancé depuis « Aujourd'hui » reste « Planifiées » (hors U8,
  `[U-9]` du plan du catalogue).

## 12. Réalisation (écarts au plan)

- **Titre de l'accueil** : `Aujourd'hui · <date>` (et `Today · <date>`), pas
  « Aujourd'hui » seul : la nouvelle étiquette ne duplique ainsi pas celle de la
  navigation (`findsOneWidget`). Le titre de page `homeTitle` est retiré.
- **« Planifier une séance »** : le bouton existant `homeOpenPlanner` est
  conservé en bas de l'accueil (24 scénarios l'utilisent) ; « Planifier la
  prochaine séance » est le titre de la carte vide.
- **Ex aequo** : départage par identifiant d'élève (comparaison de chaînes,
  sensible à la casse), stable mais **non alphabétique** (« Zoé » avant
  « alex »). Choix assumé.
- **`RunningSession`** est dans `features/run_sheet/presentation/bloc/` (elle
  porte `RunKey`). **Dette de placement assumée** : `RunKey` est défini dans la
  couche présentation de `run_sheet` ; tant qu'il n'est pas descendu dans un
  `domain` (ou `shared/lib`), `RunningSession` reste à côté et l'accueil
  l'atteint par `RunningSessionsCubit`. Déplacer les deux est un lot à part
  (touche la séance guidée, ses tests et la persistance de reprise).
- **Titres d'exercices** : `blockLabels` ajouté à `WatchList` et `SessionReview`
  (le plan n'en parlait pas ; sans lui l'écran ne pouvait nommer l'exercice).
- **`WatchRow`** (`shared/ui`) partagé par l'accueil et le bilan, au lieu d'un
  `StudentChip` : le niveau d'alerte est écrit en texte, sans rouge.
- **Bilan sans passage** : la liste « À surveiller » et « Présents sans
  passage » restent affichées ; seule la séance suivante est masquée.
- **Date en dehors de la saison** : le sélecteur est borné à demain et à un an
  (bornes calculées par `plannableDates(today)`, domaine `review_session`, sans
  dépendre de la date déjà choisie : aujourd'hui exclu, demain et aujourd'hui + 1
  an inclus) ;
  le refus de `PlanSession` (`seasonOutsidePeriod`) est montré par
  `NextSheetCard` avec « Ouvrir le planificateur » (test de widget, pas de
  scénario BDD : atteindre une date hors saison dans le sélecteur est fragile).
- **Section en échec** : couverte par `test/unit/pages/home_page_test.dart`.
- Les scénarios BDD d'interface sont dans `home.feature` (26) et
  `session_review.feature` (15) ; `design_system.feature` (badges de public) et
  `localization`, `navigation`, `screen_navigation` ont été adaptés.

### Mineurs de la revue indépendante (corrigés)

| # | Mineur | Statut |
|---|--------|--------|
| 1 | Règle d'alertes dupliquée | Corrigé : un seul comparateur `compareWatched` (niveau, échecs décroissants, identifiant de l'élève) ; l'accueil ne retrie plus ; scénario BDD « ex aequo dans le même ordre à l'accueil et au bilan ». Le départage par prénom est abandonné. |
| 2 | Bornes du sélecteur de date du bilan | Corrigé : `plannableDates(today)` (domaine), tests aux valeurs exactes et test de widget. |
| 3 | « Validé aujourd'hui » faux sur un bilan rouvert | Corrigé : « Validé pendant cette séance » / « Validated during this session ». |
| 4 | Clés ARB mortes | Retirées : `homeTitle`, `homeSubtitle`, `homeAudiencesTitle` (`reviewSeeSuggestion`, ajoutée puis retirée dans le lot, ne figure pas dans le diff). Dette antérieure retirée aussi : `commonDecrease`, `commonIncrease`, `guideShowHint`, `plannerAudienceField`, `sheetAlertsTitle`, `sheetLatestAssessment`, `sheetNoAssessment`, `studentsNoAlert`. |
| 5 | Libellé d'accessibilité de `WatchRow` | Clé ARB paramétrée `watchRowLabel` (fr + en), test de sémantique en français. |
| 6 | Commentaire de `SuggestNextSheet` | Corrigé : décrit la délégation à `SuggestSession`. |
| 7 | Assertions faibles | Valeurs exactes (`'a'`, `'Bloc a'`). |
| 8 | Notion « séance à venir » dupliquée | Non unifiée, volontairement : les deux règles diffèrent. `upcomingOf` (accueil) retient les séances **à partir d'aujourd'hui** (une séance du jour sans saisie reste à donner) ; le bilan retient les séances **strictement après** aujourd'hui (la séance du jour est celle qu'on vient de donner). Une méthode `Session.isUpcoming` unique cacherait cette différence. |
| 9 | Placement de `RunningSession` | Dette documentée ci-dessus (§ 12). |

### Constats du parcours web d'U8 (hors lot, à traiter)

- Une saisie le jour J marque « faites » toutes les séances planifiées ce
  jour-là pour le groupe (ADR 0007) : l'accueil peut annoncer « Aucune séance
  n'est planifiée » alors qu'une autre séance du même jour reste planifiée.
- À 320 dp, le libellé « Aujourd'hui » de la barre du bas se coupe en
  « Aujourd'h / ui ».
