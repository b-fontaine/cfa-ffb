# Lien séance planifiée ↔ saisie : correction du défaut D1 (plan)

Statut : **implémenté le 2026-10-16** (lots L1 à L3 ; points [U] au défaut
proposé ; L4 non fait ; parcours web Playwright et revues indépendantes non faits). Le fichier de reproduction a été fusionné dans les tests
unitaires puis supprimé. Décision : [ADR 0016](adr/0016-identite-de-la-saisie-par-groupe-jour-et-seance.md).
Origine : défaut D1 du parcours web d'U4 ([guide-mener-plan.md § 18](guide-mener-plan.md))
et « Aujourd'hui » ([aujourdhui-plan.md § 2.3](aujourdhui-plan.md)). Amende la
décision 2 et la limite de l'[ADR 0007](adr/0007-lien-seance-planifiee-saisie-catalogue.md).
Règles de développement : `AGENTS.md`, skills `dev-feature`, `dev-bdd`, `dev-tdd`.

## 1. Défaut reproduit et cause confirmée

Test de reproduction : `app/test/unit/features/plan_session/d1_link_repro_test.dart`
(**rouge constaté** ; fichier à fusionner dans `list_sessions_test.dart` et
`open_or_resume_session_test.dart` au lot L1 puis à supprimer). Mise en place :
groupe `g1`, saisie du 12 avec la séance du catalogue `posture-1`, séance
planifiée le 12 pour `g1` avec `demi-bille-2`. Trois tests, trois rouges :

1. `ListSessions` : attendu `recordId == null`, obtenu `'x-posture'`.
2. `GetUpcomingSessions` (horloge 12 octobre) : attendu `next.session.id ==
   'p-demi'`, obtenu `null` (l'accueil dit « Aucune séance n'est planifiée »).
3. **D1 bis, plus grave que le constat d'origine** : « Noter » sur la séance
   planifiée appelle `OpenOrResumeSession(sheetId: demi-bille-2)`, qui **reprend
   la saisie `posture-1` du même jour et réécrit son `sheetId`** en
   `demi-bille-2` : une seule saisie reste (attendu 2), et la séance du
   catalogue de la première est perdue. Ce n'est pas qu'un défaut d'affichage :
   il corrompt la donnée (et donc `givenSheets`, ADR 0009).

Cause (lecture du code) :

- `features/plan_session/domain/list_sessions.dart:33-37` : `recordId` = première
  saisie du groupe avec `record.date.isSameDayAs(session.date)`. **La séance du
  catalogue n'est pas comparée.**
- `features/record_results/domain/open_or_resume_session.dart:42-45` : une
  saisie existante pour (groupe, jour) est reprise quelle que soit la séance
  demandée ; `:63` `sheet = sheetId ?? first.sheetId` puis `:68-73` `copyWith(
  sheetId: sheet)` réécrit la séance de la saisie reprise.
- `features/plan_session/domain/upcoming_sessions.dart:45-47,59` : « prochaine »
  et « à noter » filtrent sur `summary.recordId == null` ; ils héritent du
  défaut sans en être la cause.
- Aucune contrainte d'unicité (groupe, jour) en base ni dans la sauvegarde
  (`backup_uniqueness.dart` ne contrôle que les identifiants) : deux saisies le
  même jour sont déjà **stockables et importables**. Seule `OpenOrResumeSession`
  les empêche. L'historique les départage déjà (`list_recorded_sessions.dart`,
  ordre de première sauvegarde), et `home.feature:54-61` suppose déjà plusieurs
  séances planifiées le même jour.

## 2. Inventaire : qui dérive « saisie faite pour cette séance planifiée »

| Endroit | Dérivation | Change ? |
|---|---|---|
| `ListSessions` (`list_sessions.dart:31-38`) → `PlannedSessionSummary.recordId` : liste « Planifiées » (« Noter les résultats » / « Résultats saisis », `session_list.dart:164-190`) | (groupe, jour) | **Oui** : règle partagée (§ 4) |
| `OpenOrResumeSession` (`:42-45`, `:62-67`) : « Noter » depuis Planifiées, Aujourd'hui, guide, suggestion, formulaire manuel | (groupe, jour) | **Oui** : même règle ; ne réécrit plus la séance d'une saisie d'une autre séance |
| `upcomingOf` (`upcoming_sessions.dart:45-64`) : « prochaine séance », « + N autres », « à noter » | `recordId == null` | Non (code) ; hérite de `ListSessions` ; commentaires et tests à jour |
| Cartes d'« Aujourd'hui » (`upcoming_cards.dart`), `onRecord(group, date, sheet)` | `recordId`, transmet déjà `sheet` | Non |
| Guide « Noter » (`router.dart:997-1010`, `record_sheet.dart:100-115`, `RunSheetState.recordDefaults`, `RunRecordChoice.recordId`) | transmet toujours `sheet = séance du guide` ; retient l'identifiant de saisie ouverte | Non : corrigé par `OpenOrResumeSession` ; scénario de non-régression |
| Bilan `GetSessionReview` (`:68-73`, `plannedFor(sheet)`) | séances **à venir** du groupe, par séance du catalogue | Non : ne dérive pas « saisie faite » |
| Séance suggérée « faite » (ADR 0009, `givenSheets`, `GetGroupJourney`, `SuggestSession`) | `SessionRecord.sheetId` + passages ; indépendant des planifiées | Non (bénéficie de la fin de la réécriture de `sheetId`) |
| Historique (`ListRecordedSessions`) | saisies seules, tri date puis ordre de sauvegarde | Non : deux saisies du jour s'affichent déjà |
| Vue de groupe (`groupAttendance`, `GetWeekSummary.sessions`) | une saisie = une séance donnée | Non ; effet à connaître : deux saisies un jour comptent pour deux (point U-3) |
| Sauvegarde (encodeur, décodeur, `BackupRules`, format 3) | aucun lien stocké | Non ; scénarios de non-régression |

## 3. Options

Remarque commune : filtrer seulement l'affichage (**A0**, `ListSessions`) est
**insuffisant et dangereux** : la séance planifiée redevient « à noter », mais
« Noter » reprend la saisie de l'autre séance et la réécrit (D1 bis). Toute
option doit donc changer aussi la règle de reprise.

| | Principe | Coût | Risque de régression | Verdict |
|---|---|---|---|---|
| **A+** (recommandée) | Aucune colonne. Règle unique « la saisie d'une séance planifiée » = (groupe, jour, séance du catalogue), `null` compatible avec tout (§ 4), appliquée par `ListSessions` **et** `OpenOrResumeSession` | 1 fonction pure en `entities`, 2 appelants, ~15 tests, 6 scénarios ; **0 migration, 0 changement de sauvegarde** | Faible : seul change le cas « deux séances du catalogue **différentes** le même jour pour un groupe » (aujourd'hui fusionnées, d'où le défaut) | **Retenue** |
| **B** | `SessionRecord.plannedSessionId` (colonne nullable, schéma v9 `addColumn`, sauvegarde v4, décodeur tolérant l'absence de clé, repli) | Migration + instantané + test de migration + format de sauvegarde + routes (`?planned=`) + guide (`RunKey.sessionId` → saisie) + références à vérifier à l'import | Moyen à élevé : tout chemin d'ouverture doit porter le lien ; liens orphelins (planifiée supprimée) ; **il faut quand même le repli A+** pour les saisies existantes et celles sans lien | Reporté : à faire seulement si le cas « deux séances identiques le même jour » devient réel (U-5). A+ en est le préalable, rien n'est à défaire |
| C | Imposer une seule séance planifiée par (groupe, jour) | Garde à la planification + message | Contredit `home.feature:54-61`, ne répare ni les données existantes ni les saisies ouvertes ailleurs | Rejetée |
| D | Lien porté par la planifiée (`Session.recordId`) | Migration v9, écriture dans deux entités à chaque saisie, cohérence à tenir | Élevé (deux sources de vérité) | Rejetée |

### Réponses aux cas demandés (option A+)

- **Saisie ouverte « sans séance planifiée »** (suggestion sans séance du
  catalogue, formulaire manuel, saisie ancienne `sheetId == null`) : elle reste
  une saisie du groupe ce jour-là. Une séance planifiée du même groupe et du
  même jour, avec ou sans séance du catalogue, la **reprend** (règle `null`
  compatible, comportement actuel conservé : « Noter » stampe alors la séance du
  catalogue sur cette saisie, tests existants `open_or_resume_session_test`).
  Limite assumée : une saisie libre du jour « absorbe » une planifiée du même
  jour (U-1).
- **Deux planifiées le même jour, même groupe, séances du catalogue
  différentes** : deux saisies distinctes, chacune liée à la sienne ; « Noter »
  sur la seconde ouvre une seconde saisie sans toucher la première. C'est le
  correctif.
- **Deux planifiées le même jour, même groupe, même séance du catalogue** (ou
  deux sans séance) : indiscernables, elles partagent **la même saisie** (une
  fois la saisie faite, les deux affichent « Résultats saisis »). Pas de boucle
  « Noter » sans fin : la saisie reprise est la même. Seul un lien explicite
  (option B) les distinguerait (U-5).
- **Saisie d'une planifiée supprimée** : la saisie reste (historique, suivi) ;
  aucun lien stocké donc rien d'orphelin. Replanifier la même séance le même
  jour la fait réapparaître « saisie », comme aujourd'hui.
- **Planifiée « déplacée »** : il n'y a pas d'édition (suppression puis
  replanification, `delete_session.dart`). La nouvelle date n'a pas de saisie :
  « à noter » ; la saisie de l'ancienne date reste attachée à son jour, ce qui
  est exact (la séance a été donnée ce jour-là).
- **Données existantes** : aucune migration, aucune réécriture ; les saisies et
  sauvegardes JSON déjà exportées (format 1 à 3) s'importent à l'identique. Les
  saisies dont `sheetId` a déjà été réécrit par D1 bis ne se retrouvent pas
  (information perdue, non reconstituable).

## 4. Décision : règle unique

Placement : `entities/session_record/domain/record_matching.dart` (Dart pur,
sans horloge), appelé par les deux features sans import latéral.

- `bool sameSitting(SheetId? a, SheetId? b) => a == null || b == null || a == b`.
- `SessionRecord? recordFor(Iterable<SessionRecord> records, DateTime day,
  SheetId? sheet)` : parmi les saisies du **même jour** (`isSameDayAs`), celles
  où `sameSitting(record.sheetId, sheet)` ; **préférence** à l'égalité exacte
  (y compris `null == null`), sinon la première dans l'ordre de sauvegarde.
- `ListSessions` : `recordId = recordFor(saisiesDuGroupe, session.date,
  session.sheetId)?.id`.
- `OpenOrResumeSession` : `existing = recordFor(...)` ; absent → `OpenSession` ;
  présent → reprise comme aujourd'hui (la séance du catalogue demandée complète
  une saisie qui n'en avait pas, ne remplace **jamais** une séance différente :
  ce cas n'arrive plus puisque `recordFor` l'écarte).
- Aucun changement de schéma, de sauvegarde, de route ni de chaîne i18n.

## 5. Lots d'implémentation (ordre)

| Lot | Contenu | Critère de fin |
|---|---|---|
| **L1** | Scénarios BDD § 6 + steps (`a session is recorded … without a catalogue session`, `… the history lists N sessions`, etc.) + tests unitaires § 6 ; fusion du fichier de reproduction | Tout **rouge constaté** sur de vraies assertions, avant L2 ; rouge listé |
| **L2** | Domaine (TDD) : `record_matching.dart`, `ListSessions`, `OpenOrResumeSession` ; commentaires de `PlannedSessionSummary`, `upcoming_sessions.dart` | Unitaires et BDD verts ; scénarios existants inchangés et verts |
| **L3** | Parcours web (Playwright : planifier « La puissance 1/2 » un jour où une autre saisie existe ; accueil ; Noter ; historique), ADR 0016 passé à « accepté », mise à jour de l'ADR 0007 (décision 2, limite), `seance-planifiee-plan.md` § 2, `aujourdhui-plan.md` § 2.3, `guide-mener-plan.md § 18` (D1 soldé), `architecture.md`, roadmap, `scripts/check.sh --full`, revues `architecte-fsd` + `testeur-bdd` en contextes séparés | Garde-fous verts, revues sans réserve bloquante |
| (L4) | Option B, **seulement si U-5 est tranché oui** : schéma v9 (`make-migrations`, instantané, test de migration sur base v8 avec saisies), sauvegarde v4 rétrocompatible (clé absente = repli A+), import refusé sans écriture partielle sur lien inconnu, routes | Non planifié |

## 6. Tests à écrire d'abord (liste exacte)

Scénarios BDD (anglais Gherkin, libellés `en`, « aujourd'hui » = lundi 12 octobre) :

`home.feature`
1. *A session planned for today is the next session although another catalogue session was recorded today* : planifiée `posture-2` le 12, saisie `posture-1` le 12 ; on voit la carte « prochaine » et **pas** « No session planned ».
2. *A past planned session is offered to be noted although another catalogue session was recorded that day* : planifiée `posture-2` le 8, saisie `posture-1` le 8 ; « Note the results » proposé.
3. *Two sessions planned the same day: the recorded one is done, the other stays next* : planifiées `posture-1` et `posture-2` le 12, saisie `posture-1` le 12 ; la prochaine est `posture-2`, sans « + 1 autre ».

`session_planner.feature`
4. *A planned session offers to note the results although another catalogue session was recorded the same day* (« Note the results », pas « Results recorded »).
5. *Noting the second session of the day opens a second record and keeps the first* : après « Note the results » puis « Open the session », la planifiée passe à « Results recorded » ; la première saisie garde sa séance du catalogue.
6. *A record without catalogue session is taken for the planned session of the day* (compatibilité, U-1).
7. *Deleting a planned session keeps its record* (la saisie reste dans « Results »).

`session_guide.feature`
8. *Noting from the guide of the second session of the day opens a new record* (lancer la planifiée n° 2 depuis Planifiées, « Note » d'un exercice, la saisie n° 1 n'est pas modifiée).

`record_history.feature`
9. *Two sessions recorded the same day for a group are both listed with their catalogue session*.

`data_backup.feature`
10. *Restoring two records of the same group on the same day keeps both* (aller-retour) : **écrit** (`data_backup.feature`, « Restaurer deux saisies d'un même groupe le même jour » ; mutation temporaire de l'encodeur constatée rouge puis restaurée).
11. ~~*A backup of format 3 restores planned sessions linked to their record by catalogue session*~~ : **retiré le 2026-10-16**. Le format 3 est le format courant (`BackupCodec.currentVersion`) : le scénario existant « Conserver la date, le groupe et la séance du catalogue des séances » est déjà l'aller-retour d'une sauvegarde de format 3 avec séance planifiée et saisie liées par la séance du catalogue ; aucun fichier de format 3 figé n'existe dans les tests, et la règle A+ ne stocke aucun lien : un second scénario testerait la même chose.

Tests unitaires (TDD, rouge puis vert) :

- `record_matching_test` : mêmes jour et séance → trouvée ; autre jour → non ; séances différentes → non ; `null` côté saisie → oui ; `null` côté demandée → oui ; préférence à l'égalité exacte sur le `null` ; ordre de sauvegarde en dernier recours ; autre groupe exclu (par l'appelant).
- `list_sessions_test` : les 3 tests de `d1_link_repro_test` (D1, upcoming, bis) ; deux planifiées aux séances différentes → deux `recordId` distincts ; deux identiques → même `recordId` ; planifiée sans séance → saisie du jour.
- `open_or_resume_session_test` : séance différente le même jour → nouvelle saisie, première intacte (`sheetId`, blocs, présents) ; séance identique → reprise ; saisie sans séance + séance demandée → reprise et séance posée (existant) ; séance demandée absente + saisie avec séance → reprise (existant) ; séance inconnue → `unknownSheet` sans écriture (existant).
- `get_upcoming_sessions_test` : D1 (prochaine non nulle).
- `upcoming_sessions_test` : inchangé (ne lit que `recordId`) ; ajouter un cas deux séances du jour avec une seule `recordId`.

**Scénarios existants impactés** : aucun ne doit changer de résultat, à
**vérifier au vert** (honnêtement non constaté à ce stade). Proches de la
règle : `home.feature:46-52` (même séance `posture-1` saisie et planifiée : reste
« faite »), `session_planner.feature` « Noting the results… » et « A planned
session already recorded… » (même séance), `open_or_resume_session_test` (cinq
tests de reprise avec `null`), `list_sessions_test` (planifiée et saisie toutes
deux sans séance). Les tests `d1_link_repro_test` sont les seuls rouges
d'aujourd'hui.

## 7. Risques

- **Régression silencieuse de la reprise** (le plus important) : toute ouverture
  de saisie passe par `OpenOrResumeSession` ; la préférence « exact avant
  `null` » et le comportement `null` compatible sont couverts par les tests
  existants plus ceux de L1.
- **Deux saisies un même jour** : apparaissent déjà (import, historique) mais
  deviennent courantes ; assiduité et « séances données » les comptent chacune
  (U-3) ; l'historique les distingue par la séance du catalogue (déjà affichée).
- **Absorption par une saisie libre** (U-1) : un défaut D1 résiduel existe quand
  l'autre saisie du jour n'a **pas** de séance du catalogue ; il n'est pas
  traité (le corriger casserait la reprise depuis le formulaire manuel).
- Données déjà corrompues par D1 bis : non récupérables, à signaler à
  l'animateur.
- Fichiers générés : aucun (pas de freezed, pas de drift, pas de l10n touchés).

## 8. Points `[U]` pour l'animateur (proposition par défaut)

| # | Question | Défaut proposé |
|---|---|---|
| U-1 | Une saisie du jour **sans** séance du catalogue (libre, suggestion sans séance, ancienne) vaut-elle saisie d'une séance planifiée du même groupe et du même jour ? | **Oui** (comportement actuel ; évite les doublons quand on revient sur la saisie). Alternative : strictement non, au prix d'un doublon possible depuis le formulaire manuel |
| U-2 | Deux séances planifiées identiques (même groupe, jour, séance) : avertir à la planification ? | Non ; elles partagent la saisie, documenté |
| U-3 | Deux saisies le même jour comptent-elles pour deux séances dans l'assiduité du groupe et les « 7 derniers jours » ? | Oui (deux séances réellement données) |
| U-4 | Une planifiée **sans** séance du catalogue est-elle « saisie » dès qu'une saisie du jour existe, quelle que soit sa séance ? | Oui (rien ne permet de distinguer) |
| U-5 | Faut-il un lien explicite planifiée → saisie (option B) pour distinguer deux séances identiques le même jour ? | Non, à rouvrir si le cas se présente |
| U-6 | Informer l'animateur des saisies d'avant correction dont la séance a été réécrite ? | Non (indétectable) |
