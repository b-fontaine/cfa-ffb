# Lier séance planifiée, saisie et séance du catalogue : plan

Statut : **livré** (lot 6 de la [roadmap](roadmap.md) ; conception validée
par l'utilisateur le 2026-10-14 : lot complet, lien dérivé par groupe et
date, date obligatoire ; lots P1 à P5 réalisés le 2026-10-14, `scripts/check.sh
--full` vert, revues `architecte-fsd` et `testeur-bdd` prises en compte :
Widgetbook recompilé, libellé de public partagé, priorité « choix précédent
puis séance planifiée » portée par `RunSheetState.recordDefaults`, règle du
rappel dérivé centralisée dans `SheetBlocks.resolve`, bornes de saison et
aller-retour de sauvegarde assertés). Décision :
[ADR 0007](adr/0007-lien-seance-planifiee-saisie-catalogue.md).
Contexte : application V1 non livrée, aucune compatibilité de données à
préserver. Règles de développement : `AGENTS.md`, skills `dev-feature`,
`dev-bdd`, `dev-tdd` ; `architecture.md`, `testing.md`, `quality-gates.md`,
`design-system.md`, `i18n.md`.

## 1. Constat et objectif

Une séance planifiée (`Session`) n'a ni date ni groupe (friction F6) ; elle
n'est liée à rien d'autre que, depuis l'ADR 0004, la séance du catalogue
qu'elle suit. « Lancer » ouvre la séance guidée, et « Noter les résultats »
redemande le groupe, la date et les présents. La séance saisie
(`SessionRecord`) ne sait pas quelle séance du catalogue elle note : seuls le
bloc principal et le bloc de rappel sont conservés. Objectif : planifier une
séance **pour un groupe, à une date**, la lancer, noter ses résultats sans
rien ressaisir, et retrouver depuis la planification comme depuis l'historique
la séance du catalogue suivie.

## 2. Décisions (reprises de l'ADR 0007)

1. `Session` porte une **date obligatoire** (jour) et un **groupe facultatif**
   (`GroupId?`). Avec un groupe, le public est celui du groupe et la date doit
   tomber dans sa saison (`seasonOutsidePeriod`, même règle que l'ouverture de
   saisie) ; sans groupe, le public reste choisi à la main (club sans groupe).
2. Le lien planifiée ↔ saisie est **dérivé** : une séance planifiée est
   « saisie » quand une `SessionRecord` du **même groupe** existe le **même
   jour** (règle déjà appliquée par `OpenOrResumeSession`). Aucune clé
   étrangère, rien à sauvegarder.
3. `SessionRecord` porte la **séance du catalogue** qu'elle note (`SheetId?`).
   À l'ouverture, la notion principale et le rappel de résultats absents sont
   **dérivés** de cette séance (`catalogueBlock`, `resultsRecallBlock`) ; une
   séance inconnue du catalogue est refusée (`unknownSheet`). À l'affichage, un
   identifiant inconnu ne lève jamais (ligne « séance du catalogue » absente).
4. **« Lancer » puis « Noter »** : le guide lancé depuis une séance planifiée
   pré-remplit le groupe et la date de la saisie (le choix d'une saisie
   précédente du même guide reste prioritaire) et transmet la séance du
   catalogue. La ligne planifiée propose **« Noter les résultats »** (groupe
   connu) et, une fois la saisie faite, **« Résultats saisis »** qui l'ouvre.
5. Persistance : schéma drift **v4** ; sauvegarde JSON de même version avec les
   clés `date`, `groupId` (séances planifiées) et `sheetId` (séances saisies).
6. `SheetOption` (identifiant, technique, titre, partie) descend en
   `entities/session_sheet/domain` avec la fonction pure `sheetOptionsOf` :
   planification, saisie et historique libellent la même chose.
7. Hors lot : rattacher après coup une saisie ouverte sans planification ;
   deux saisies le même jour pour un groupe (la seconde reprend la première,
   comportement existant) ; assiduité du groupe (lot 10).

## 3. Écrans

### Planification (`/planner`)

- Formulaire : titre, séance du catalogue (inchangé), **groupe** (sélecteur en
  feuille : « Aucun groupe (public au choix) » puis les groupes de la saison en
  cours, « Jeunes · Enfants »), **public** (verrouillé sur celui du groupe
  choisi), **date** (jour courant par défaut, « Modifier la date »), Ajouter.
  Une règle refusée (date hors saison, groupe disparu) s'affiche sous le bouton
  comme à l'ouverture de saisie.
- Liste **triée par date croissante** (puis ordre de planification). Ligne :
  titre ; « lun. 12 oct. · Jeunes · Enfants · 90 min » (sans groupe : « lun.
  12 oct. · Enfants · 90 min » ; groupe disparu : « Groupe indisponible ») ;
  « Séance du catalogue : … » ou « Choisir une séance » (inchangé) ; actions :
  **Lancer** (séance du catalogue connue), **Noter les résultats** (groupe
  connu, pas encore saisie), **Résultats saisis** (ouvre `/record/:id`),
  Supprimer.

### Séance guidée

Inchangée visuellement. « Noter les résultats » depuis un guide lancé d'une
séance planifiée ouvre `/record/new` avec `group`, `date` et `sheet` ; le
premier choix fait dans la saisie reste repris aux exercices suivants.

### Saisie (`/record/new`, `/record/:sessionId`) et historique (`/record`)

- `/record/new` accepte `sheet` (identifiant de séance du catalogue) en plus de
  `group`, `date`, `main`, `recall`, `exercise`, `from`, `absent`.
- Sous-titre de la saisie et ligne de l'historique : « Jeunes · Séance du
  catalogue : La puissance, séance 1/2 » quand la séance est connue, sinon la
  notion principale comme aujourd'hui.

## 4. Découpage FSD

| Couche | Slice | Ajouts / modifications |
|---|---|---|
| `entities` | `session/domain` | `Session.date`, `Session.groupId` ; `data` : colonnes drift, `in_memory` inchangé |
| `entities` | `session_record/domain` | `SessionRecord.sheetId` ; `data` : colonne drift |
| `entities` | `session_sheet/domain` | `SheetOption` + `sheetOptionsOf` (depuis `features/plan_session`), `resultsRecallBlock` (depuis `features/run_sheet`) |
| `entities` | `group/domain` | `currentGroups(groups, seasons, today)` (règle de `GetClubOverview`, réutilisée) |
| `features` | `plan_session/domain` | `PlanSession(date, groupId)`, `ListSessions` → `PlannedSessionSummary` (séance, groupe, saisie) triés, `ListPlannableGroups` |
| `features` | `plan_session/presentation` | bloc : `groups`, `selectedGroup`, `date`, `failure` ; formulaire : sélecteur de groupe, date |
| `features` | `record_results/domain` | `ResolveSheetBlocks`, `OpenSession`/`OpenOrResumeSession(sheetId)`, `SessionOverview.sheet`, `RecordedSessionSummary.sheet` |
| `features` | `record_results/presentation` | `OpenSessionEvent.requested(sheetId)`, ligne « séance du catalogue » |
| `features` | `run_sheet/domain` | `RunPlan.planned` (séance planifiée lue par `ResolveRunPlan`) |
| `features` | `backup_data/domain` | encodeur, décodeur, références, règles |
| `widgets` | `session_list` | résumés, date, groupe, actions Noter / Résultats saisis |
| `pages` | `session_planner`, `record_setup`, `record_session` | callbacks `onRecord`, `onOpenRecord` ; `sheetId` ; sous-titre |
| `app` | `router` | `AppRoutes.recordFromPlan`, `recordFromGuide(sheet)`, paramètre `sheet`, `today` au planificateur |
| `shared` | `lib` | `DateOnly` (même jour) ; `persistence` : schéma v4, migration `from3To4` |

## 5. Domaine : règles

- `PlanSession` : titre non vide ; groupe inconnu → `unknownGroup` ; date hors
  saison du groupe → `seasonOutsidePeriod` ; public = celui du groupe.
- `ListSessions` : tri par date croissante puis ordre de planification ;
  `recordId` = séance saisie du même groupe le même jour (première trouvée).
- `ResolveSheetBlocks(sheetId)` : `(main: catalogueBlock, recall:
  resultsRecallBlock)` ; inconnu → `unknownSheet`. `OpenSession` ne dérive que
  les blocs **absents** ; un rappel dérivé égal au bloc principal est ignoré.
- `OpenOrResumeSession` : la reprise conserve la séance du catalogue existante
  si aucune n'est donnée.
- Sauvegarde : `groupId` d'une séance planifiée doit exister
  (`backupInconsistent`) ; public ≠ groupe ou date hors saison →
  `backupInvalid` ; `sheetId` inconnu (planifiée ou saisie) →
  `backupUnknownSheet`.
- Migration v4 : `planned_sessions` recréée avec `date` non nulle (lignes
  existantes : `date = created_at`) et `group_id` nullable ;
  `session_records.sheet_id` nullable.

## 6. Scénarios BDD (rouge avant le code)

`session_planner.feature` : date et groupe sur la ligne ; public pris du
groupe ; tri par date ; « Noter les résultats » ouvre la saisie pré-remplie et
la saisie connaît la séance du catalogue ; « Résultats saisis » ouvre la
saisie. `session_guide.feature` : un guide lancé depuis une séance planifiée
pré-remplit groupe et date. `record_history.feature` : la ligne nomme la
séance du catalogue. `data_backup.feature` : aller-retour avec date, groupe et
séance du catalogue. Lignes existantes « Children · 90 min » → « Mon, Oct 12 ·
Children · 90 min ».

## 7. Lots

| Lot | Contenu | Critère de fin |
|---|---|---|
| P1 | Plan, ADR, scénarios BDD + steps (rouge) | `.feature` générés, tests rouges constatés |
| P2 | Domaine (TDD) : entités, `currentGroups`, `SheetOption`, `resultsRecallBlock`, `PlanSession`, `ListSessions`, `ListPlannableGroups`, `ResolveSheetBlocks`, ouverture, aperçus, `RunPlan.planned`, sauvegarde | tests unitaires verts |
| P3 | Persistance : schéma v4, migration, instantanés, dépôts drift | `migration_test` vert |
| P4 | Blocs, l10n fr/en, routes, formulaire, liste, pages, Widgetbook | scénarios BDD verts, `check_widgetbook` vert |
| P5 | Docs (`architecture.md`, ADR 0001, ADR 0004, `guide-animateur.md`, roadmap), `check.sh --full`, revues `architecte-fsd` + `testeur-bdd` | tout vert, revues sans réserve bloquante |

## 8. Risques

- Première migration drift qui **recrée** une table (`TableMigration`) : testée
  sur une base v3 avec une séance planifiée (date = création) et une séance
  saisie (séance du catalogue nulle).
- Lien dérivé : deux séances planifiées le même jour pour un groupe pointent la
  même saisie ; documenté (ADR 0007, § hors lot).
- `Session.date` obligatoire change la signature de toutes les fixtures
  (`const Session(...)` devient non constant) ; aucun contournement, les tests
  sont mis à jour.
